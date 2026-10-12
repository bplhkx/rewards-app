import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/mjpeg.dart';
import '../core/util.dart';
import '../core/tokens.dart';
import '../widgets/glass_dock.dart';
import '../widgets/ui.dart';

/// 接管视图：MJPEG 画面 + 点按回传 + 交还按钮。
class ViewPage extends StatefulWidget {
  const ViewPage({super.key, required this.base, required this.token});
  final String base;
  final String token;

  @override
  State<ViewPage> createState() => _ViewPageState();
}

class _ViewPageState extends State<ViewPage> {
  MjpegStream? _stream;
  StreamSubscription? _sub;
  Uint8List? _frame;
  (int, int)? _size; // 画面真实宽高，从 JPEG SOF 段解出来
  Map<String, dynamic>? _st;
  String? _err;
  Timer? _poll;

  String get _url => '${widget.base}/view?t=${widget.token}';

  @override
  void initState() {
    super.initState();
    _start();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sub?.cancel();
    _stream?.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (widget.token.isEmpty) return;
    try {
      final api = Api(base: widget.base, token: widget.token);
      final s = await api.get('/status');
      if (mounted) setState(() => _st = s is Map<String, dynamic> ? s : null);
    } catch (_) {}
  }

  void _start() {
    _stream?.dispose();
    _sub?.cancel();
    setState(() {
      _frame = null;
      _size = null;
      _err = widget.token.isEmpty ? '未配置视图 token' : null;
    });
    if (widget.token.isEmpty) return;
    final s = MjpegStream(_url);
    _stream = s;
    _sub = s.stream.listen(
      (f) {
        if (mounted) setState(() => _frame = f);
      },
      onError: (e) {
        if (mounted) setState(() => _err = '画面流中断：${errText(e)}');
      },
    );
    s.start().catchError((e) {
      if (mounted) setState(() => _err = errText(e));
    });
  }

  /// 解 JPEG 的 SOF 段拿宽高，点按换算要用
  static (int, int)? jpegSize(Uint8List f) {
    for (var i = 2; i < f.length - 9; i++) {
      if (f[i] != 0xFF) continue;
      final m = f[i + 1];
      if (m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC) {
        final h = (f[i + 5] << 8) | f[i + 6];
        final w = (f[i + 7] << 8) | f[i + 8];
        if (w > 0 && h > 0) return (w, h);
      }
    }
    return null;
  }

  Future<void> _input(String type, Offset pos, Size box) async {
    final f = _frame;
    if (f == null) return;
    _size ??= jpegSize(f);
    final s = _size;
    if (s == null) return;
    // contain 布局下画面实际占的矩形
    final aspect = s.$1 / s.$2;
    var w = box.width, h = box.height;
    if (w / h > aspect) {
      w = h * aspect;
    } else {
      h = w / aspect;
    }
    final dx = (box.width - w) / 2, dy = (box.height - h) / 2;
    final nx = ((pos.dx - dx) / w).clamp(0.0, 1.0);
    final ny = ((pos.dy - dy) / h).clamp(0.0, 1.0);
    final api = Api(base: widget.base, token: widget.token);
    try {
      await api.post('/input', {'type': type, 'x': nx, 'y': ny, 'button': 0});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final active = _st?['active'] == true;
    return ListView(
      padding: EdgeInsets.fromLTRB(T.pagePad, T.pagePad, T.pagePad, GlassDock.reserve(context) + T.gap),
      children: [
        PanelCard(
          padding: const EdgeInsets.symmetric(horizontal: T.gap, vertical: 10),
          child: Row(children: [
            Icon(Icons.visibility_rounded, size: 18, color: active ? T.green500 : T.slate400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                active ? '实时画面 ｜ ${_st?['reason'] ?? ''}' : '视图未开启（bot 跑起来后才有画面）',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            if (active) ...[
              Pill('帧 ${_st?['frames'] ?? 0}', color: T.primary),
              const SizedBox(width: 6),
              Pill('观看 ${_st?['viewers'] ?? 0}', color: T.slate500),
            ],
          ]),
        ),
        const SizedBox(height: T.gap),
        if (_err != null) ErrorBanner(_err!, onRetry: _start),
        PanelCard(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            height: 300,
            child: _frame == null
                ? Center(
                    child: _err == null
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Icon(Icons.videocam_off_outlined, size: 34, color: T.slate400),
                  )
                : LayoutBuilder(
                    builder: (context, c) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _input('down', d.localPosition, Size(c.maxWidth, c.maxHeight)),
                      onTapUp: (d) => _input('up', d.localPosition, Size(c.maxWidth, c.maxHeight)),
                      child: Image.memory(_frame!, fit: BoxFit.contain, gaplessPlayback: true),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: T.gap),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: active
                  ? () async {
                      final api = Api(base: widget.base, token: widget.token);
                      try {
                        await api.post('/resume');
                      } catch (_) {}
                      _refreshStatus();
                    }
                  : null,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('交还给自动流程'),
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: T.md),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(width: T.gap),
          Expanded(
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重连画面'),
              style: FilledButton.styleFrom(
                  backgroundColor: T.primary,
                  shape: RoundedRectangleBorder(borderRadius: T.md),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text('点画面 = 回传点击给无头浏览器',
            style: TextStyle(fontSize: 11, color: T.subText(context))),
      ],
    );
  }
}
