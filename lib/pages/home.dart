import 'dart:async';

import 'package:flutter/material.dart';

import '../core/panel.dart';
import '../core/tokens.dart';
import '../core/util.dart';
import '../widgets/trend_chart.dart';
import '../widgets/ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.panel});
  final Panel panel;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _summary;
  List<dynamic> _runs = [];
  Map<String, dynamic> _accounts = {};
  String? _err;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await widget.panel.get('/api/summary');
      final r = await widget.panel.get('/api/runs', {'limit': '30'});
      final a = await widget.panel.get('/api/accounts', {'historyDays': '7'});
      if (!mounted) return;
      setState(() {
        _summary = s is Map<String, dynamic> ? s : null;
        _runs = (pick(r is Map<String, dynamic> ? r : null, ['runs']) as List?) ?? [];
        _accounts = a is Map<String, dynamic> ? a : {};
        _err = null;
      });
    } catch (e) {
      if (mounted) setState(() => _err = errText(e));
    }
  }

  Future<void> _act(String action) async {
    setState(() => _busy = true);
    try {
      // 启停经面板代理，面板再转发给 bot 的 /start、/stop；App 里没有 token
      await widget.panel.post('/api/control/$action', const <String, dynamic>{});
      await Future.delayed(const Duration(milliseconds: 800));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> get _status =>
      (_summary?['status'] is Map<String, dynamic>) ? _summary!['status'] as Map<String, dynamic> : {};

  /// 面板把 bot 自己的 /status 原样放在 status.bot 里（state / run / live 都在那儿）
  Map<String, dynamic> get _bot =>
      (_status['bot'] is Map<String, dynamic>) ? _status['bot'] as Map<String, dynamic> : {};
  Map<String, dynamic> get _run =>
      (_bot['run'] is Map<String, dynamic>) ? _bot['run'] as Map<String, dynamic> : {};
  Map<String, dynamic> get _live =>
      (_run['live'] is Map<String, dynamic>) ? _run['live'] as Map<String, dynamic> : {};
  bool get _reachable => _status['reachable'] == true;
  bool get _running => _status['botRunning'] == true;
  String get _stateLabel => _reachable ? pickStr(_bot, ['state'], 'idle').toUpperCase() : 'DISCONNECTED';

  List<({String label, int value})> get _trend {
    final byDay = <String, int>{};
    for (final r in _runs) {
      if (r is! Map<String, dynamic>) continue;
      final ts = pickStr(r, ['start_ts', 'startTs', 'id']);
      final dt = DateTime.tryParse(ts)?.toLocal();
      if (dt == null) continue;
      final key = '${dt.month}/${dt.day}';
      byDay[key] = (byDay[key] ?? 0) + pickInt(r, ['total_gained', 'totalGained']);
    }
    final now = DateTime.now();
    final out = <({String label, int value})>[];
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.month}/${d.day}';
      out.add((label: key, value: byDay[key] ?? 0));
    }
    return out;
  }

  int get _today => _trend.last.value;

  int get _balance {
    final hist = _accounts['histories'];
    if (hist is! Map) return 0;
    var sum = 0;
    for (final v in hist.values) {
      if (v is List && v.isNotEmpty) {
        final last = v.last;
        if (last is Map) sum += pickInt(last.cast<String, dynamic>(), ['points']);
      }
    }
    return sum;
  }

  int get _accountCount => (_accounts['accounts'] as List?)?.length ?? 0;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(T.pagePad),
        children: [
          if (_err != null) ...[ErrorBanner(_err!, onRetry: _load), const SizedBox(height: T.gap)],
          _statusCard(context),
          const SizedBox(height: T.gap),
          Row(children: [
            StatTile(icon: Icons.bolt_rounded, label: '今日', value: '+$_today', tint: T.green500),
            const SizedBox(width: T.gap),
            StatTile(icon: Icons.account_balance_wallet_outlined, label: '余额', value: '$_balance', tint: T.primary),
            const SizedBox(width: T.gap),
            StatTile(icon: Icons.people_outline, label: '账号', value: '$_accountCount', tint: T.purple500),
          ]),
          const SizedBox(height: T.gap),
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('近 7 天'),
              const SizedBox(height: 8),
              TrendChart(days: _trend),
            ]),
          ),
          const SizedBox(height: T.gap),
          PanelCard(
            padding: const EdgeInsets.symmetric(horizontal: T.gap, vertical: 4),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const SectionTitle('最近运行'),
                if (_runs.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('还没有运行记录')),
                ..._runs.take(5).map((r) {
                  final m = r is Map<String, dynamic> ? r : <String, dynamic>{};
                  final ok = pickStr(m, ['status']) == 'done';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
                        size: 18, color: ok ? T.green500 : T.red500),
                    title: Text(
                      '${pickStr(m, ['start_ts', 'startTs', 'id']).replaceFirst('T', ' ').substring(0, 16)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Pill(ok ? '+${pickInt(m, ['total_gained', 'totalGained'])}' : pickStr(m, ['status']),
                        color: ok ? T.green500 : T.red500),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final live = _live;
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: _running ? T.green500 : T.slate400,
                borderRadius: T.pill,
              ),
            ),
            const SizedBox(width: 8),
            Text(!_reachable ? '面板连不上 bot' : (_running ? '运行中' : '空闲'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            Pill(_stateLabel, color: _running ? T.green500 : (_reachable ? T.slate500 : T.red500)),
          ]),
          const SizedBox(height: 10),
          if (!_reachable) ...[
            Text(pickStr(_status, ['lastError'], '面板说 Control API 不可达'),
                style: TextStyle(fontSize: 12, color: T.subText(context))),
            const SizedBox(height: 10),
          ],
          if (_running) ...[
            Text(
              '当前 ${pickStr(live, ['currentAccount'], '…')} ｜ 本轮 +${pickInt(live, ['gained'])}',
              style: TextStyle(fontSize: 12, color: T.subText(context)),
            ),
            const SizedBox(height: 10),
          ],
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: T.primary,
                  shape: RoundedRectangleBorder(borderRadius: T.md),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _busy || _running || !_reachable ? null : () => _act('start'),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('开始一轮'),
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: T.red500,
                  side: const BorderSide(color: T.red500),
                  shape: RoundedRectangleBorder(borderRadius: T.md),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _busy || !_running ? null : () => _act('stop'),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('停止'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
