import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  const ApiFailure(
    this.code, {
    this.status = 0,
    this.retryable = false,
    this.requestId,
  });
  final String code;
  final int status;
  final bool retryable;
  final String? requestId;
}

/// Only this service knows HTTP, credentials and the wire error structure.
class ApiClient {
  ApiClient(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client() {
    final uri = Uri.parse(baseUrl);
    if (baseUrl.isNotEmpty &&
        uri.scheme != 'https' &&
        !(kDebugMode &&
            ['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host))) {
      throw ArgumentError('HTTPS is required');
    }
  }
  final String baseUrl;
  final http.Client _client;
  String locale = 'th';
  String? accessToken;
  int sessionVersion = 0;
  Future<bool> Function()? refreshSession;
  void Function()? onSessionExpired;
  Future<bool>? _refreshing;

  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = true,
    bool allowEmpty = false,
    bool readList = false,
  }) => request(
    'GET',
    path,
    authenticated: authenticated,
    allowEmpty: allowEmpty,
    readList: readList,
  );
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? requestKey,
    bool authenticated = true,
    bool allowEmpty = false,
    bool retryAuth = true,
    bool readList = false,
    bool readEvents = false,
  }) async {
    if (!path.startsWith('/api/')) {
      throw ArgumentError('Only business API paths are allowed');
    }
    final uri = Uri.parse('$baseUrl$path');
    final requestSessionVersion = sessionVersion;
    final headers = <String, String>{
      'Accept': readEvents ? 'text/event-stream' : 'application/json',
      'Content-Type': 'application/json',
      'Accept-Language': locale,
      if (authenticated && accessToken != null)
        'Authorization': 'Bearer $accessToken',
      'Idempotency-Key': ?requestKey,
    };
    late http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 35)),
      ).timeout(Duration(seconds: readEvents ? 75 : 35));
    } on TimeoutException {
      throw const ApiFailure('timeout', retryable: true);
    } on http.ClientException {
      throw const ApiFailure('network_error', retryable: true);
    }
    if (authenticated && requestSessionVersion != sessionVersion) {
      throw const ApiFailure('session_changed', status: 401);
    }
    if (response.statusCode == 401 && authenticated) {
      if (retryAuth && refreshSession != null) {
        _refreshing ??= refreshSession!();
        bool refreshed;
        try {
          refreshed = await _refreshing!;
        } finally {
          _refreshing = null;
        }
        if (sessionVersion != requestSessionVersion) {
          throw const ApiFailure('session_changed', status: 401);
        }
        if (refreshed) {
          return request(
            method,
            path,
            body: body,
            requestKey: requestKey,
            authenticated: true,
            allowEmpty: allowEmpty,
            retryAuth: false,
            readList: readList,
            readEvents: readEvents,
          );
        }
      }
      onSessionExpired?.call();
    }
    dynamic decoded;
    if (readEvents && response.statusCode >= 200 && response.statusCode < 300) {
      return _chatReply(response.body);
    }
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw ApiFailure('invalid_response', status: response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map ? decoded['error'] : null;
      throw ApiFailure(
        error is Map && error['code'] is String
            ? error['code'] as String
            : decoded is Map && decoded['code'] is String
            ? decoded['code'] as String
            : 'request_failed',
        status: response.statusCode,
        retryable: error is Map
            ? error['retryable'] == true
            : response.statusCode >= 500,
        requestId: error is Map ? error['request_id'] as String? : null,
      );
    }
    if (decoded == null && allowEmpty) return {};
    if (readList && decoded is List) return {'items': decoded};
    if (decoded is! Map<String, dynamic>) {
      throw const ApiFailure('invalid_response');
    }
    return decoded;
  }

  void close() => _client.close();

  // Only the server's final done event confirms a saved conversation.
  Map<String, dynamic> _chatReply(String body) {
    var event = '';
    final answer = StringBuffer();
    String? messageId;
    try {
      for (final line in const LineSplitter().convert(body)) {
        if (line.startsWith('event:')) event = line.substring(6).trim();
        if (!line.startsWith('data:')) continue;
        final data = jsonDecode(line.substring(5).trim());
        if (data is! Map<String, dynamic>) {
          throw const FormatException('invalid_event');
        }
        if (event == 'error') {
          throw ApiFailure(data['code'] as String? ?? 'request_failed');
        }
        if (event == 'token') answer.write(data['text'] as String);
        if (answer.length > 24000) {
          throw const FormatException('reply_too_long');
        }
        if (event == 'done') messageId = data['message_id'] as String?;
      }
    } on FormatException {
      throw const ApiFailure('invalid_response');
    } on TypeError {
      throw const ApiFailure('invalid_response');
    }
    if (messageId == null ||
        messageId.isEmpty ||
        answer.toString().trim().isEmpty) {
      throw const ApiFailure('reply_incomplete', retryable: true);
    }
    return {'id': messageId, 'content': answer.toString()};
  }
}
