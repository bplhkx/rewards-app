import 'dart:convert';
import 'dart:io';

/// 面板（rewards-dashboard）客户端。App 只认这一个入口：
/// 读走面板自己的 sqlite（/api/summary、/api/accounts、/api/runs、/api/logs），
/// 需要动 bot 的（启停、参数、远端定时）面板都有代理端点，token 留在服务端，App 不碰。
/// 面板可能开了 Basic auth，也可能没开（手机那台就关着），两种都支持。
class Panel {
  Panel({required this.base, this.user = '', this.pass = ''});

  String base;
  String user;
  String pass;

  bool get _authed => user.isNotEmpty && pass.isNotEmpty;

  Map<String, String> get _headers => {
        if (_authed) 'Authorization': 'Basic ${base64Encode(utf8.encode('$user:$pass'))}',
      };

  Future<dynamic> get(String path, [Map<String, String>? q]) =>
      _send('GET', path, query: q);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final req = await HttpClient()
        .openUrl(method, Uri.parse(base + path).replace(queryParameters: query))
        .timeout(const Duration(seconds: 10));
    _headers.forEach((k, v) => req.headers.set(k, v));
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close().timeout(const Duration(seconds: 20));
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode == 401) throw PanelError('面板要密码（401），去"更多"里填用户和密码');
    if (res.statusCode >= 400) {
      // 面板的错误都是 {error:"..."}，直接把这句话说给人看，别甩一堆 HTTP 码
      final msg = _errOf(text);
      throw PanelError(msg ?? '面板 HTTP ${res.statusCode}${method == 'GET' ? '' : '（$method $path）'}');
    }
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }

  static String? _errOf(String text) {
    try {
      final j = jsonDecode(text);
      if (j is Map && j['error'] is String) return j['error'] as String;
    } catch (_) {}
    return null;
  }

  /// 视图页要直连接管服务（8891），用的是另一套客户端（core/api.dart），这里不掺和 SSE。
}

class PanelError implements Exception {
  PanelError(this.message);
  final String message;
  @override
  String toString() => message;
}
