import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Control API 客户端。所有请求带 Bearer token；SSE 用 /events。
class Api {
  Api({required this.base, required this.token});

  String base; // e.g. http://192.0.2.1:3010
  String token;

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse(base + path).replace(queryParameters: q);


  Future<dynamic> get(String path, [Map<String, String>? q]) async {
    final req = await HttpClient()
        .openUrl('GET', _u(path, q))
        .timeout(const Duration(seconds: 10));
    req.headers.set('Authorization', 'Bearer $token');
    final res = await req.close().timeout(const Duration(seconds: 15));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode == 401) throw ApiError('token 不对（401）');
    if (res.statusCode != 200) throw ApiError('HTTP ${res.statusCode}');
    return jsonDecode(body);
  }

  Future<dynamic> post(String path, [Object? body]) async {
    final req = await HttpClient()
        .openUrl('POST', _u(path))
        .timeout(const Duration(seconds: 10));
    req.headers.set('Authorization', 'Bearer $token');
    req.headers.contentType = ContentType.json;
    if (body != null) req.write(jsonEncode(body));
    final res = await req.close().timeout(const Duration(seconds: 20));
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 400) {
      throw ApiError('HTTP ${res.statusCode} ${text.length > 120 ? text.substring(0, 120) : text}');
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final req = await HttpClient()
        .openUrl('PATCH', _u(path))
        .timeout(const Duration(seconds: 10));
    req.headers.set('Authorization', 'Bearer $token');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    final res = await req.close().timeout(const Duration(seconds: 20));
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 400) {
      throw ApiError('HTTP ${res.statusCode} ${text.length > 160 ? text.substring(0, 160) : text}');
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  /// 跑一轮：不传 = 全部账号；accountIndex = 只跑一个；excluded = 跑除这些之外的（批量选择用这个）
  Future<dynamic> startRun({int? accountIndex, List<int>? excluded}) {
    if (accountIndex != null && excluded != null && excluded.isNotEmpty) {
      throw ApiError('accountIndex 与 excludedAccountIndexes 不能同时给');
    }
    final body = <String, dynamic>{};
    if (accountIndex != null) body['accountIndex'] = accountIndex;
    if (excluded != null && excluded.isNotEmpty) body['excludedAccountIndexes'] = excluded;
    return post('/start', body);
  }

  /// SSE：yield 每一条 event 的 (name, json)
  Stream<SseEvent> events() async* {
    final client = HttpClient();
    final req = await client.openUrl('GET', _u('/events', {'token': token}));
    req.headers.set('Accept', 'text/event-stream');
    req.headers.set('Cache-Control', 'no-cache');
    final res = await req.close();
    String name = '';
    StringBuffer data = StringBuffer();
    await for (final raw in res.transform(utf8.decoder).transform(const LineSplitter())) {
      if (raw.isEmpty) {
        if (data.isNotEmpty) {
          yield SseEvent(name.isEmpty ? 'message' : name, data.toString());
        }
        name = '';
        data = StringBuffer();
        continue;
      }
      if (raw.startsWith('event:')) {
        name = raw.substring(6).trim();
      } else if (raw.startsWith('data:')) {
        data.write(raw.substring(5).trim());
      }
    }
    client.close(force: true);
  }
}

class SseEvent {
  SseEvent(this.name, this.data);
  final String name;
  final String data;
  Map<String, dynamic>? get json {
    try {
      final v = jsonDecode(data);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }
}

class ApiError implements Exception {
  ApiError(this.message);
  final String message;
  @override
  String toString() => message;
}
