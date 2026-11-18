import '../core/network/api_client.dart';

class CompanionRepository {
  const CompanionRepository(this.api);
  final ApiClient api;

  Future<List<Map<String, dynamic>>> _list(String path) async {
    final value = await api.get(path, readList: true);
    final items = value['items'];
    if (items is! List) throw const ApiFailure('invalid_response');
    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> history() => _list('/api/history');
  Future<void> clearHistory() async {
    await api.request('DELETE', '/api/history');
  }

  Future<List<Map<String, dynamic>>> memories() => _list('/api/memories');
  Future<Map<String, dynamic>> send({
    required String message,
    required String provider,
    required String context,
    String? period,
  }) => api.request(
    'POST',
    '/api/chat',
    readEvents: true,
    body: {
      'message': message,
      'provider': provider,
      'context': context,
      'period': ?period,
    },
  );

  Future<Map<String, dynamic>> saveMemory(String content, {String? id}) async {
    final saved = await api.request(
      id == null ? 'POST' : 'PUT',
      id == null ? '/api/memories' : '/api/memories/${Uri.encodeComponent(id)}',
      body: {'content': content},
    );
    if (saved['id'] is! String || saved['content'] is! String) {
      throw const ApiFailure('invalid_response');
    }
    return saved;
  }

  Future<void> deleteMemory(String id) async {
    await api.request('DELETE', '/api/memories/${Uri.encodeComponent(id)}');
  }
}
