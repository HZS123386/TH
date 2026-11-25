import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'models.dart';

abstract interface class DeviceStore {
  String ownerKey();
}

class AppLoginCode {
  const AppLoginCode(this.value, this.expiresAt);

  final String value;
  final DateTime expiresAt;
  bool get expired => !expiresAt.isAfter(DateTime.now());
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
  String action,
  Map<String, String> fields,
});

class ReportRepository {
  static const _reportReadTimeout = Duration(seconds: 15);
  static const _marriagePreviewWait = Duration(seconds: 60);

  ReportRepository(this.store, {http.Client? client, this.baseUrl = ''})
    : client = client ?? http.Client();
  final DeviceStore store;
  final http.Client client;
  final String baseUrl;
  final _firstCityPages = <String, Future<Json>>{};
  String language = 'th';
  Json Function()? visitContext;
  void Function(String, String, String)? onClientFailure;

  void _recordClientFailure(String path, String code, String method) {
    if (path.split('?').first == '/api/landing/visits') return;
    try {
      final template = path
          .split('?')
          .first
          .replaceFirst(
            RegExp(r'^/api/life-reports/[^/]+'),
            '/api/life-reports/{report_id}',
          )
          .replaceFirst(
            RegExp(r'^/api/landing/visits/[^/]+'),
            '/api/landing/visits/{visit_id}',
          );
      onClientFailure?.call(template, code, method);
    } catch (_) {
      // Optional diagnostics cannot replace the original error.
    }
  }

  Future<dynamic> request(
    String path,
    CancelToken token, {
    Json? body,
    bool owned = true,
    String? method,
    Duration? timeout,
  }) async {
    token.check();
    final headers = {
      'Accept-Language': language,
      if (body != null) 'Content-Type': 'application/json',
      if (owned) 'X-Report-Key': store.ownerKey(),
    };
    try {
      final visit = visitContext?.call() ?? {};
      if (visit['id'] is String) {
        headers.addAll({
          'X-Visit-Id': visit['id'] as String,
          'X-Report-Key': store.ownerKey(),
        });
      }
    } catch (_) {
      // Public location lookups remain usable if optional browser storage fails.
    }
    final requestMethod = method ?? (body == null ? 'GET' : 'POST');
    final deadline = Completer<void>();
    final request = http.AbortableRequest(
      requestMethod,
      Uri.parse('$baseUrl$path'),
      abortTrigger: Future.any([token.future, deadline.future]),
    )..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      Future<http.Response> receive() async =>
          http.Response.fromStream(await client.send(request));
      response = timeout == null
          ? await receive()
          : await receive().timeout(
              timeout,
              onTimeout: () {
                deadline.complete();
                throw const ApiFailure('network');
              },
            );
    } catch (_) {
      token.check();
      _recordClientFailure(path, 'network', requestMethod);
      throw const ApiFailure('network');
    }
    token.check();
    if (response.statusCode == 204) return null;
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      _recordClientFailure(path, 'badResult', requestMethod);
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
    if (data == null) {
      _recordClientFailure(path, 'badResult', requestMethod);
      throw const ApiFailure('badResult');
    }
    return data;
  }

  Future<LifeReport> load(
    String id,
    CancelToken token, {
    bool waitForPreview = false,
    Duration timeout = _reportReadTimeout,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(id)) {
      throw const ApiFailure('missing');
    }
    return LifeReport.parse(
      await request(
        '/api/life-reports/$id${waitForPreview ? '?wait_preview=true' : ''}',
        token,
        timeout: timeout,
      ),
      id: id,
    );
  }

  Future<LifeReport> generate(
    Json input,
    CancelToken token,
    void Function(LifeReport, double, String) progress, {
    Json visit = const {},
  }) async {
    final initial = await request(
      '/api/life-reports?wait=false',
      token,
      body: {...input, if (visit.isNotEmpty) 'landing_visit': visit},
      timeout: input['report_kind'] == 'marriage' ? _reportReadTimeout : null,
    );
    return _wait(initial, input, token, false, progress);
  }

  Future<AppLoginCode> createAppLoginCode(
    String reportId,
    CancelToken token,
  ) async {
    final result = object(
      await request(
        '/api/life-reports/${Uri.encodeComponent(reportId)}/app-login-code',
        token,
        body: const {},
        timeout: const Duration(seconds: 10),
      ),
    );
    final code = text(result['code']), lifetime = result['expires_in'];
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code) ||
        lifetime is! int ||
        lifetime <= 0 ||
        lifetime > 600) {
      throw const ApiFailure('badResult');
    }
    return AppLoginCode(code, DateTime.now().add(Duration(seconds: lifetime)));
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

  Future<LifeReport> resumeGeneration(
    LifeReport initial,
    CancelToken token,
    void Function(LifeReport, double, String) progress, {
    required bool full,
  }) =>
      _wait(initial.json, initial.input, token, full, progress, id: initial.id);

  Future<PaymentOrder> createPayment(
    LifeReport report,
    CancelToken token,
  ) async {
    final order = object(
      await request('/api/life-reports/${report.id}/payment', token, body: {}),
    );
    return _paymentOrder(report, order);
  }

  Future<PaymentOrder?> existingPayment(
    LifeReport report,
    CancelToken token,
  ) async {
    final order = await request(
      '/api/life-reports/${report.id}/payment',
      token,
    );
    return order == null ? null : _paymentOrder(report, object(order));
  }

  Future<({List<String> methods, bool checkPayment})> paymentMethods(
    LifeReport report,
    CancelToken token,
  ) async {
    final result = object(
      await request(
        '/api/life-reports/${report.id}/payment/methods',
        token,
        timeout: const Duration(seconds: 35),
      ),
    );
    final methods = result['methods'];
    final checkPayment = result['check_payment'];
    if (methods is! List ||
        methods.any((method) => method is! String) ||
        checkPayment is! bool) {
      throw const ApiFailure('badResult');
    }
    return (methods: methods.cast<String>(), checkPayment: checkPayment);
  }

  Future<String?> startPayment(
    LifeReport report,
    String method,
    CancelToken token,
  ) async {
    final result = object(
      await request(
        '/api/life-reports/${report.id}/payment/start',
        token,
        body: {'method': method},
        timeout: const Duration(seconds: 55),
      ),
    );
    final value = result['redirect_url'];
    if (value == null && result.containsKey('redirect_url')) return null;
    final url = value is String ? Uri.tryParse(value) : null;
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      throw const ApiFailure('badResult');
    }
    return value as String;
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
          (order['order_only'] != true ||
              order['state'] != 'CREATED' ||
              !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(gatewayOrder))) {
        throw const ApiFailure('badResult');
      }
      return (
        reference: reference,
        gatewayOrder: gatewayOrder,
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
    final elapsed = Stopwatch()..start();
    const interval = Duration(seconds: 2);
    var previousReadSeconds = interval.inSeconds;
    while (true) {
      token.check();
      final report = LifeReport.parse(value, id: id, expectedInput: input);
      id = report.id;
      if (full && !report.full) throw const ApiFailure('badResult');
      final percent = report.percent(full);
      final state = text(report.json[full ? 'full_state' : 'preview_state']);
      final queue = object(report.json['generation_queue']);
      final phase = state == 'queued'
          ? 'queued'
          : full
          ? 'full'
          : queue['state'] == 'calculating'
          ? 'calculating'
          : 'preview';
      progress(report, percent, phase);
      if (percent == 100) return report;
      if (state == 'pending') throw const ApiFailure('busy');
      if (!(full ? report.fullInProgress : report.previewInProgress)) {
        throw ApiFailure('${full ? 'states' : 'previewStates'}.$state');
      }
      Duration limited(Duration duration) {
        if (full || !report.marriageReport) return duration;
        final remaining = _marriagePreviewWait - elapsed.elapsed;
        if (remaining <= Duration.zero) {
          throw const ApiFailure('previewStates.unavailable');
        }
        return duration < remaining ? duration : remaining;
      }

      // Count the server's wait toward the polling budget.
      var delay = full
          ? interval
          : Duration(
              seconds: (interval.inSeconds - previousReadSeconds).clamp(
                0,
                interval.inSeconds,
              ),
            );
      while (true) {
        await token.pause(limited(delay));
        final timeout = limited(_reportReadTimeout);
        try {
          final started = Stopwatch()..start();
          value = (await load(
            id,
            token,
            waitForPreview: !full,
            timeout: timeout,
          )).json;
          previousReadSeconds = started.elapsed.inSeconds;
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

  Future<void> warmCities(String country) async {
    try {
      await _firstCityPage(country);
    } on ApiFailure {
      // An unsuccessful preload is retried when the visitor opens the list.
    }
  }

  Future<Json> _firstCityPage(String country) =>
      _firstCityPages.putIfAbsent(country, () async {
        try {
          return await _fetchCities(
            country,
            '',
            0,
            CancelToken(),
            timeout: const Duration(seconds: 12),
          );
        } catch (_) {
          _firstCityPages.remove(country);
          rethrow;
        }
      });

  Future<Json> cities(
    String country,
    String query,
    int offset,
    CancelToken token,
  ) async {
    token.check();
    if (query.isEmpty && offset == 0) {
      // A closed menu cancels its own wait. The next menu can reuse the request.
      final result = await Future.any<Json>([
        _firstCityPage(country),
        token.future.then<Json>((_) => throw const Cancelled()),
      ]);
      token.check();
      return result;
    }
    return _fetchCities(country, query, offset, token);
  }

  Future<Json> _fetchCities(
    String country,
    String query,
    int offset,
    CancelToken token, {
    Duration? timeout,
  }) async {
    final params = Uri(
      queryParameters: {
        'country': country,
        'level': country == 'CN' || country == 'TH' ? 'locality' : 'city',
        'query': query,
        'offset': '$offset',
      },
    ).query;
    return object(
      await request(
        '/api/thai-locations?$params',
        token,
        owned: false,
        timeout: timeout,
      ),
    );
  }
}
