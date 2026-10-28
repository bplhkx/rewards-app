import 'dart:async';

import 'package:flutter/material.dart';

import '../core/panel.dart';
import '../core/tokens.dart';
import '../core/util.dart';
import '../widgets/glass_dock.dart';
import '../widgets/ui.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.panel});
  final Panel panel;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<Map<String, dynamic>> _rows = [];
  String? _err;
  String _level = '';
  Timer? _timer;
  final ScrollController _sc = ScrollController();
  /// 自动跟随最新行。用户往上滑就暂停，滑回底部再恢复 —— 
  /// 否则每 5 秒一次的刷新会把人正在看的那几行顶走。
  bool _follow = true;
  /// 暂停那一刻的行数，用来算"落后几条"
  int _anchorLen = 0;

  static const _levels = ['', 'info', 'warn', 'error'];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final q = {'limit': '150'};
      if (_level.isNotEmpty) q['level'] = _level;
      final d = await widget.panel.get('/api/logs', q);
      final list = (d is Map ? (d['logs'] as List?) : (d as List?)) ?? [];
      if (!mounted) return;
      setState(() {
        // 面板按时间升序给，直接顺着画就是"旧在上、新在下"的终端读法
        _rows = list.whereType<Map<String, dynamic>>().toList();
        _err = null;
      });
      if (_follow) _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _err = errText(e));
    }
  }

  /// 新行落在列表底部，所以要先布局完再跳 —— postFrame 里 maxScrollExtent 才是新值
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sc.hasClients) return;
      _sc.jumpTo(_sc.position.maxScrollExtent);
    });
  }

  void _setFollow(bool v) {
    if (_follow == v) return;
    setState(() {
      _follow = v;
      _anchorLen = _rows.length;
    });
    if (v) _scrollToBottom();
  }

  int get _behind => _follow ? 0 : (_rows.length - _anchorLen).clamp(0, 9999);

  Color _levelColor(String l) => switch (l) {
        'error' => T.red500,
        'warn' => T.amber500,
        'debug' => T.purple500,
        _ => T.green500,
      };

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(T.pagePad, T.pagePad, T.pagePad, 8),
        child: Row(children: [
          for (final l in _levels)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(l.isEmpty ? '全部' : l, style: const TextStyle(fontSize: 11)),
                selected: _level == l,
                shape: RoundedRectangleBorder(borderRadius: T.pill),
                selectedColor: T.primaryLight,
                side: BorderSide(color: T.hairline(context)),
                onSelected: (_) => setState(() => _level = l),
              ),
            ),
          const Spacer(),
          // 自动滚动的状态要看得见、也能手动按住（有些人就是想停在某一行看）
          IconButton(
            tooltip: _follow ? '自动滚动中 · 点按暂停' : '已暂停自动滚动 · 点按恢复',
            onPressed: () => _follow ? _setFollow(false) : _setFollow(true),
            icon: Icon(
              _follow ? Icons.vertical_align_bottom : Icons.pause_circle_outline,
              size: 18,
              color: _follow ? T.primary : T.slate400,
            ),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, size: 18)),
        ]),
      ),
      Expanded(
        child: _err != null
            ? Padding(padding: const EdgeInsets.all(T.pagePad), child: ErrorBanner(_err!, onRetry: _load))
            : _rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(T.pagePad),
                    child: PanelCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
                        child: Text(
                          '暂无日志（缓冲在 bot 内存，重启即清空）',
                          style: TextStyle(fontSize: 12.5, height: 1.6, color: T.subText(context)),
                        ),
                      ),
                    ),
                  )
                : Stack(children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        // 只有用户自己拖的那次才算"我要回头看"，程序 jumpTo 不触发这里
                        if (n is ScrollUpdateNotification && n.dragDetails != null && _sc.hasClients) {
                          final pos = _sc.position;
                          final nearBottom = pos.pixels >= pos.maxScrollExtent - 30;
                          if (!nearBottom && _follow) _setFollow(false);
                          if (nearBottom && !_follow) _setFollow(true);
                        }
                        return false;
                      },
                      child: ListView.builder(
                          controller: _sc,
                          padding: EdgeInsets.fromLTRB(T.pagePad, 0, T.pagePad, GlassDock.reserve(context)),
                          itemCount: _rows.length,
                          itemBuilder: (context, i) {
                            final r = _rows[i];
                            final level = pickStr(r, ['level'], 'info');
                            final ts = pickStr(r, ['ts', 'timestamp', 'time']);
                            final title = pickStr(r, ['title']);
                            final msg = pickStr(r, ['message', 'msg']);
                            final who = pickStr(r, ['user_name', 'userName']);
                            final plat = pickStr(r, ['platform']);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: T.surface(context),
                                borderRadius: T.md,
                                border: Border.all(color: T.hairline(context)),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Container(width: 6, height: 6, decoration: BoxDecoration(color: _levelColor(level), borderRadius: T.pill)),
                                  const SizedBox(width: 6),
                                  Text(logClock(ts),
                                      style: TextStyle(fontSize: 10, color: T.subText(context))),
                                  const SizedBox(width: 8),
                                  Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _levelColor(level))),
                                  const Spacer(),
                                  if (who.isNotEmpty)
                                    Text('${who.substring(0, who.length > 6 ? 6 : who.length)}${plat.isNotEmpty ? "/$plat" : ""}',
                                        style: TextStyle(fontSize: 9, color: T.subText(context))),
                                ]),
                                const SizedBox(height: 4),
                                Text(msg, style: const TextStyle(fontSize: 11, height: 1.35)),
                              ]),
                            );
                          },
                        ),
                    ),
                    // 暂停跟随时给个回得去的入口，不然要自己滑半天
                    if (_behind > 0)
                      Positioned(
                        right: T.pagePad,
                        // 悬浮 dock 浮在内容上，这颗按钮要停在它上面
                        bottom: GlassDock.reserve(context) - 16,
                        child: FilledButton.icon(
                          onPressed: () => _setFollow(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: T.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: T.pill),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                          label: Text('最新 $_behind 条', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                  ]),
      ),
    ]);
  }
}
