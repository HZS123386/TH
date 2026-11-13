import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'models.dart';

abstract interface class DeviceStore {
  String ownerKey();
}

class Cancelled implements Exception {
  const Cancelled();
}

class CancelToken {
  final _done = Completer<void>();
  Future<void> get future => _done.future;
  bool get cancelled => _done.isCompleted;
  void cancel() {
    if (!cancelled) _done.complete();
  }

  void check() {
    if (cancelled) throw const Cancelled();
  }

  Future<void> pause(Duration delay) async {
    check();
    final tick = Completer<void>();
    final wake = Timer(delay, tick.complete);
    try {
      await Future.any([tick.future, future]);
      check();
    } finally {
      wake.cancel();
    }
  }
}

class ApiFailure implements Exception {
  const ApiFailure(this.code, {this.status = 0, this.retryAfter});
  final String code;
  final int status;
  final Duration? retryAfter;
}

typedef PaymentOrder = ({
  String reference,
  String gatewayOrder,
  String checkoutUrl,
  String action,
  Map<String, String> fields,
});

class ReportRepository {
  ReportRepository(this.store, {http.Client? client, this.baseUrl = ''})
    : client = client ?? http.Client();
  final DeviceStore store;
  final http.Client client;
  final String baseUrl;
  String language = 'th';
  Future<dynamic> request(
    String path,
    CancelToken token, {
    Json? body,
    bool owned = true,
    String? method,
  }) async {
    token.check();
    final headers = {
      'Accept-Language': language,
      if (body != null) 'Content-Type': 'application/json',
      if (owned) 'X-Report-Key': store.ownerKey(),
    };
    final request = http.AbortableRequest(
      method ?? (body == null ? 'GET' : 'POST'),
      Uri.parse('$baseUrl$path'),
      abortTrigger: token.future,
    )..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      response = await http.Response.fromStream(await client.send(request));
    } catch (_) {
      token.check();
      throw const ApiFailure('network');
    }
    token.check();
    if (response.statusCode == 204) return null;
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const ApiFailure('badResult');
    }
    if (response.statusCode >= 400) {
      final retry = response.headers['retry-after'];
      final seconds = double.tryParse(retry ?? '');
      DateTime? retryDate;
      if (seconds == null && retry != null) {
        try {
          retryDate = parseHttpDate(retry);
        } on FormatException {
          /* Use the conservative polling default. */
        }
      }
      final duration = seconds != null
          ? Duration(
              milliseconds: (seconds * 1000).round().clamp(0, 2147483647),
            )
          : retryDate?.difference(DateTime.now());
      throw ApiFailure(
        text(object(data)['code']).isNotEmpty
            ? text(object(data)['code'])
            : text(object(data)['detail']).isNotEmpty
            ? text(object(data)['detail'])
            : 'network',
        status: response.statusCode,
        retryAfter: duration,
      );
    }
    if (data == null) throw const ApiFailure('badResult');
    return data;
  }

  Future<LifeReport> load(String id, CancelToken token) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(id)) {
      throw const ApiFailure('missing');
    }
    return LifeReport.parse(
      await request('/api/life-reports/$id', token),
      id: id,
    );
  }

  Future<LifeReport> generate(
    Json input,
    CancelToken token,
    void Function(LifeReport, double, String) progress,
  ) async {
    final initial = await request(
      '/api/life-reports?wait=false',
      token,
      body: input,
    );
    return _wait(initial, input, token, false, progress);
  }

  Future<LifeReport> unlock(
    LifeReport initial,
    CancelToken token,
    void Function(LifeReport, double, String) progress,
  ) async {
    final result = await request(
      '/api/life-reports/${initial.id}/unlock',
      token,
      body: {},
    );
    return _wait(result, initial.input, token, true, progress, id: initial.id);
  }

  Future<PaymentOrder> createPayment(
    LifeReport report,
    CancelToken token, {
    String mobile = '',
    String nationCode = '',
  }) async {
    final order = object(
      await request('/api/life-reports/${report.id}/payment', token,
        body: report.orderOnly ? {'mobile': mobile, 'nationCode': nationCode} : {}),
    );
    return _paymentOrder(report, order);
  }

  Future<PaymentOrder?> existingPayment(LifeReport report, CancelToken token) async {
    final order = await request('/api/life-reports/${report.id}/payment', token);
    return order == null ? null : _paymentOrder(report, object(order));
  }

  PaymentOrder _paymentOrder(LifeReport report, Json order) {
    if (!report.paysoTest) {
      final reference = text(order['reference']);
      if (!RegExp(r'^[0-9]{12}$').hasMatch(reference) ||
          order['amount'] != report.price['amount'] ||
          order['currency'] != report.price['currency']) {
        throw const ApiFailure('badResult');
      }
      final gatewayOrder = text(order['order_number']);
      if (report.orderOnly &&
          (order['order_only'] != true || order['state'] != 'CREATED' ||
           !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(gatewayOrder))) {
        throw const ApiFailure('badResult');
      }
      return (
        reference: reference,
        gatewayOrder: gatewayOrder,
        checkoutUrl: text(order['checkout_url']),
        action: '',
        fields: const <String, String>{},
      );
    }
    final action = text(order['action']), fields = object(order['fields']);
    final reference = text(fields['refno']);
    if (action.isEmpty ||
        !RegExp(r'^[0-9]{12}$').hasMatch(reference) ||
        fields.values.any((value) => value is! String)) {
      throw const ApiFailure('badResult');
    }
    return (
      reference: reference,
      gatewayOrder: '',
      checkoutUrl: '',
      action: action,
      fields: Map<String, String>.from(fields),
    );
  }

  Future<void> simulatePayment(
    LifeReport report,
    PaymentOrder order,
    CancelToken token,
  ) async {
    final result = object(
      await request(
        '/api/life-reports/${report.id}/payment/simulate',
        token,
        body: {'reference': order.reference},
      ),
    );
    if (result['paid'] != true) throw const ApiFailure('badResult');
  }

  Future<bool> checkPayment(LifeReport report, CancelToken token) async {
    final result = object(
      await request(
        '/api/life-reports/${report.id}/payment/check',
        token,
        body: {},
      ),
    );
    final paid = result['paid'];
    if (paid is! bool) throw const ApiFailure('badResult');
    return paid;
  }

  Future<LifeReport> _wait(
    dynamic value,
    Json input,
    CancelToken token,
    bool full,
    void Function(LifeReport, double, String) progress, {
    String? id,
  }) async {
    var failures = 0;
    while (true) {
      token.check();
      final report = LifeReport.parse(value, id: id, expectedInput: input);
      id = report.id;
      if (full && !report.full) throw const ApiFailure('badResult');
      final percent = report.percent(full);
      progress(report, percent, full ? 'full' : 'preview');
      if (percent == 100) return report;
      final state = text(report.json[full ? 'full_state' : 'preview_state']);
      if (state == 'pending') throw const ApiFailure('busy');
      if (state != 'generating' ||
          (!full && report.json['preview_state'] == 'ready')) {
        throw ApiFailure('${full ? 'states' : 'previewStates'}.$state');
      }
      var delay = const Duration(seconds: 3);
      while (true) {
        await token.pause(delay);
        try {
          value = (await load(id, token)).json;
          failures = 0;
          break;
        } on ApiFailure catch (error) {
          if (error.status == 404) throw const ApiFailure('missing');
          if (error.status == 429) {
            final wait = error.retryAfter ?? const Duration(seconds: 60);
            delay = wait < const Duration(seconds: 3)
                ? const Duration(seconds: 3)
                : wait;
            progress(report, percent, 'waiting');
            continue;
          }
          if (++failures >= 3) throw const ApiFailure('queryError');
          delay = Duration(seconds: 3 * (1 << failures));
          progress(report, percent, 'reconnecting');
        }
      }
    }
  }

  Future<List<Place>> provinces(String country, CancelToken token) async =>
      objects(
        object(
          await request(
            '/api/thai-locations?country=$country&level=province',
            token,
            owned: false,
          ),
        )['items'],
      ).map(Place.new).toList();
  Future<Json> cities(
    String country,
    String province,
    String query,
    int offset,
    CancelToken token,
  ) async {
    final params = Uri(
      queryParameters: {
        'country': country,
        'province': province,
        'level': province.isEmpty ? 'city' : 'locality',
        'query': query,
        'offset': '$offset',
      },
    ).query;
    return object(
      await request('/api/thai-locations?$params', token, owned: false),
    );
  }
}
