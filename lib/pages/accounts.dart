import 'package:flutter/material.dart';

import '../core/panel.dart';
import '../core/tokens.dart';
import '../core/util.dart';
import '../widgets/trend_chart.dart';
import '../widgets/ui.dart';

/// 账号页：平时是只读卡片；点常驻的"批量运行"进勾选模式，然后只跑选中那几个。
/// 单跑 POST /api/control/start {accountIndex}，多选走 {excludedAccountIndexes: 未选中的序号}
/// —— 都经面板代理，App 不持有 bot 的 token。
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.panel});
  final Panel panel;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _sched;
  String? _err;
  bool _selecting = false;
  final Set<int> _picked = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.panel.get('/api/accounts', {'historyDays': '30'});
      // 定时信息顺带读一次，标题栏要显示"下次自动运行"
      Map<String, dynamic>? s;
      try {
        final raw = await widget.panel.get('/api/schedule');
        s = raw is Map<String, dynamic> ? raw : null;
      } catch (_) {
        s = null; // 读不到定时不影响账号列表
      }
      if (!mounted) return;
      setState(() {
        _data = d is Map<String, dynamic> ? d : null;
        _sched = s;
        _err = null;
      });
    } catch (e) {
      if (mounted) setState(() => _err = errText(e));
    }
  }

  List<Map<String, dynamic>> get _accounts =>
      (_data?['accounts'] as List? ?? []).whereType<Map<String, dynamic>>().toList();

  List<int> get _allIndexes => _accounts.map((a) => pickInt(a, ['index'])).toList();

  /// 面板自己的定时和 bot 的定时哪个真的会触发，就显示哪个的时间；都没开就明说，别留白。
  ({String when, String who})? get _nextRun {
    final s = _sched;
    if (s == null) return null;
    final local = s['local'] is Map ? (s['local'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final remote = s['remote'] is Map ? (s['remote'] as Map).cast<String, dynamic>() : null;
    if (local['enabled'] == true && pickStr(local, ['nextRunAt']).isNotEmpty) {
      return (when: whenText(pickStr(local, ['nextRunAt'])), who: '面板');
    }
    if (remote != null && remote['enabled'] == true && pickStr(remote, ['nextRunAt']).isNotEmpty) {
      return (when: whenText(pickStr(remote, ['nextRunAt'])), who: 'bot');
    }
    return (when: '没开', who: '定时');
  }

  Future<void> _run({int? only, List<int>? selected}) async {
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{};
      if (only != null) {
        body['accountIndex'] = only;
      } else {
        final keep = selected ?? _picked.toList();
        final excluded = _allIndexes.where((i) => !keep.contains(i)).toList();
        if (excluded.isNotEmpty) body['excludedAccountIndexes'] = excluded;
      }
      await widget.panel.post('/api/control/start', body);
      _toast(only != null ? '已启动：只跑序号 $only' : '已启动：跑 ${(selected ?? _picked).length} 个账号');
      await Future.delayed(const Duration(milliseconds: 900));
      await _load();
    } catch (e) {
      _toast('启动失败：${errText(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    final histories = (_data?['histories'] as Map?) ?? {};
    final next = _nextRun;
    return Scaffold(
      backgroundColor: T.canvas(context),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(T.pagePad, T.pagePad, 8, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_selecting ? '已选 ${_picked.length} 个' : '${accounts.length} 个账号',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (next != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: T.slate400),
                    const SizedBox(width: 4),
                    Text('下次自动运行 ${next.when}（${next.who}）',
                        style: TextStyle(fontSize: 11, color: T.subText(context))),
                  ]),
                ),
              if (_selecting)
                TextButton(onPressed: () => setState(() { _picked.addAll(_allIndexes); }), child: const Text('全选', style: TextStyle(fontSize: 12))),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh, size: 20)),
            ]),
            // 常驻入口：不进勾选模式也能一眼看到"批量运行"
            if (!_selecting)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('btn-batch'),
                    onPressed: _busy ? null : () => setState(() => _selecting = true),
                    style: FilledButton.styleFrom(
                      backgroundColor: T.primaryLight,
                      foregroundColor: T.primaryDark,
                      shape: RoundedRectangleBorder(borderRadius: T.pill),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.playlist_play_rounded, size: 16),
                    label: const Text('批量运行', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: TextButton.icon(
                  onPressed: () => setState(() { _selecting = false; _picked.clear(); }),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('退出批量', style: TextStyle(fontSize: 12.5)),
                ),
              ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(T.pagePad, 0, T.pagePad, 90),
            children: [
              if (_err != null) ...[ErrorBanner(_err!, onRetry: _load), const SizedBox(height: T.gap)],
              if (accounts.isEmpty && _err == null) const LoadingBox(height: 200),
              ...accounts.map((m) {
                final email = pickStr(m, ['email']);
                final idx = pickInt(m, ['index']);
                final hist = (histories[email] as List?) ?? [];
                final last = hist.isNotEmpty ? hist.last as Map<String, dynamic> : null;
                final points = pickInt(last, ['points']);
                final gained = pickInt(last, ['gained']);
                final streak = pickInt(m, ['streakCounter', 'successStreak']);
                final byDay = <String, int>{};
                for (final h in hist) {
                  if (h is Map<String, dynamic>) {
                    final k = dayLabel(pickStr(h, ['ts']));
                    byDay[k] = (byDay[k] ?? 0) + pickInt(h, ['gained']);
                  }
                }
                final daily = byDay.entries.toList().reversed.take(7).map((e) => (label: e.key, value: e.value)).toList();
                final checked = _picked.contains(idx);

                return Padding(
                  padding: const EdgeInsets.only(bottom: T.gap),
                  child: PanelCard(
                    onTap: _selecting ? () => setState(() => checked ? _picked.remove(idx) : _picked.add(idx)) : null,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        if (_selecting)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Checkbox(
                              value: checked,
                              activeColor: T.primary,
                              onChanged: (v) => setState(() => v == true ? _picked.add(idx) : _picked.remove(idx)),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: T.primary.withValues(alpha: 0.12), borderRadius: T.sm),
                            child: const Icon(Icons.person_outline, size: 18, color: T.primary),
                          ),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('#$idx · ${pickStr(m, ['geoLocale']).split(RegExp(r'[ |]')).first} · ${pickStr(m, ['langCode'], 'zh-CN')}',
                                style: TextStyle(fontSize: 11, color: T.subText(context))),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('$points', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: T.primary)),
                          Text('当前积分', style: TextStyle(fontSize: 10, color: T.subText(context))),
                        ]),
                        if (!_selecting)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz, size: 20),
                            onSelected: (v) {
                              if (v == 'only') _run(only: idx);
                              if (v == 'pick') setState(() { _selecting = true; _picked.add(idx); });
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'only', child: Text('只跑这个账号')),
                              PopupMenuItem(value: 'pick', child: Text('加入批量选择')),
                            ],
                          ),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        Pill('本次 +$gained', color: gained > 0 ? T.green500 : T.slate500),
                        Pill('连胜 $streak', color: T.amber500),
                        Pill('记录 ${hist.length} 次', color: T.purple500),
                        if (pickInt(m, ['streakProtectionEnabled']) == 1)
                          const Pill('🛡 保连胜', color: T.primary),
                      ]),
                      if (daily.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(height: 74, child: TrendChart(days: daily)),
                      ],
                    ]),
                  ),
                );
              }),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: _selecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(T.pagePad, 0, T.pagePad, T.pagePad),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy || _picked.isEmpty ? null : () => _run(),
                      style: FilledButton.styleFrom(backgroundColor: T.primary, shape: RoundedRectangleBorder(borderRadius: T.md), padding: const EdgeInsets.symmetric(vertical: 13)),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text('跑这 ${_picked.length} 个'),
                    ),
                  ),
                  const SizedBox(width: T.gap),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() { _selecting = false; _picked.clear(); }),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: T.md), padding: const EdgeInsets.symmetric(vertical: 13)),
                      child: const Text('取消'),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}
