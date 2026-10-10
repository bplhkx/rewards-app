import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// MJPEG 流解码：不依赖 boundary 字符串，直接在字节流里找 JPEG 的 SOI(FFD8FF) 与 EOI(FFD9)。
/// 与 Windows 侧测试脚本用的是同一套判定，边界情况（半帧、粘包）都一样处理。
class MjpegStream {
  MjpegStream(this.url);

  final String url;
  final StreamController<Uint8List> frames = StreamController.broadcast();
  HttpClient? _client;
  bool _closed = false;

  Stream<Uint8List> get stream => frames.stream;

  Future<void> start() async {
    _client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final req = await _client!.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode != 200) {
      frames.addError(HttpException('MJPEG http ${res.statusCode}'));
      return;
    }
    var buf = BytesBuilder();
    const soi = [0xFF, 0xD8, 0xFF];
    const eoi = [0xFF, 0xD9];
    await for (final chunk in res) {
      if (_closed) break;
      buf.add(chunk);
      var bytes = buf.toBytes();
      for (;;) {
        final s = _indexOf(bytes, soi, 0);
        if (s < 0) {
          // 保留尾巴两个字节，防 SOI 被切断
          bytes = bytes.length > 2 ? bytes.sublist(bytes.length - 2) : bytes;
          break;
        }
        final e = _indexOf(bytes, eoi, s + 3);
        if (e < 0) break; // 帧还没收完
        final frame = Uint8List.fromList(bytes.sublist(s, e + 2));
        if (!frames.isClosed) frames.add(frame);
        bytes = bytes.sublist(e + 2);
      }
      buf = BytesBuilder()..add(bytes);
    }
    if (!frames.isClosed) frames.close();
  }

  static int _indexOf(List<int> hay, List<int> needle, int from) {
    outer:
    for (var i = from; i <= hay.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (hay[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  void dispose() {
    _closed = true;
    _client?.close(force: true);
    if (!frames.isClosed) frames.close();
  }
}
