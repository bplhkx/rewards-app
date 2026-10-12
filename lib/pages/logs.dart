import 'dart:async';

import 'package:flutter/material.dart';

import '../core/panel.dart';
import '../core/tokens.dart';
import '../core/util.dart';
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
        _rows = list.whereType<Map<String, dynamic>>().toList().reversed.toList();
        _err = null;
      });
    } catch (e) {
      if (mounted) setState(() => _err = errText(e));
    }
  }

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
                : ListView.builder(
                controller: _sc,
                padding: const EdgeInsets.fromLTRB(T.pagePad, 0, T.pagePad, T.pagePad),
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
    ]);
  }
}
