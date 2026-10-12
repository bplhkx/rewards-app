import 'package:flutter/material.dart';

import '../core/panel.dart';
import '../core/tokens.dart';
import '../core/util.dart';
import '../widgets/ui.dart';

/// 定时任务。这里有两套彼此独立的定时：
/// · 面板自己的 scheduler（到点由面板调 /api/control/start，记 nextRunAt/上次结果）
/// · bot 容器里的 cron（写 Control API 的 /schedule，由 bot 侧 OS cron 触发）
/// 顶部切换，读写都走面板的 /api/schedule（PUT 带 target），App 不碰 bot 的 token。
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.panel});
  final Panel panel;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  Map<String, dynamic>? _local;
  Map<String, dynamic>? _remote;
  bool _remoteSupported = true;
  List<Map<String, dynamic>> _accounts = [];
  final Set<int> _excluded = {};
  bool _useRemote = false; // false=面板，true=bot
  bool _busy = false;
  String? _err;
  String? _saved;

  static const _presets = <({String label, String cron})>[
    (label: '每天 07:00', cron: '0 7 * * *'),
    (label: '每天 09:00', cron: '0 9 * * *'),
    (label: '每天 07:30 与 19:30', cron: '30 7,19 * * *'),
    (label: '工作日 08:30', cron: '30 8 * * 1-5'),
    (label: '每 12 小时', cron: '0 */12 * * *'),
  ];

  static const _misfireLabels = {
    'skip': '跳过上次的',
    'run-on-startup': '启动就补跑',
    'grace-period': '宽限期内补跑',
  };

  late final TextEditingController _cron = TextEditingController();
  late final TextEditingController _tz = TextEditingController();
  late final TextEditingController _grace = TextEditingController(text: '60');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cron.dispose();
    _tz.dispose();
    _grace.dispose();
    super.dispose();
  }

  bool get _onRemote => _useRemote;
  Map<String, dynamic>? get _cur => _onRemote ? _remote : _local;

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final s = await widget.panel.get('/api/schedule');
      final a = await widget.panel.get('/api/accounts', {'historyDays': '0'});
      if (!mounted) return;
      final m = s is Map<String, dynamic> ? s : const <String, dynamic>{};
      setState(() {
        _local = m['local'] is Map ? (m['local'] as Map).cast<String, dynamic>() : null;
        _remote = m['remote'] is Map ? (m['remote'] as Map).cast<String, dynamic>() : null;
        _remoteSupported = m['remoteSupported'] == true;
        if (_onRemote && _remote == null) _useRemote = false;
        _accounts = (a is Map ? (a['accounts'] as List? ?? []) : const []).whereType<Map<String, dynamic>>().toList();
        _applyForm();
        _busy = false;
      });
    } catch (e) {
      if (mounted) setState(() { _err = errText(e); _busy = false; });
    }
  }

  void _applyForm() {
    final cur = _cur ?? const <String, dynamic>{};
    _cron.text = pickStr(cur, ['cron'], '0 9 * * *');
    _tz.text = pickStr(cur, ['timezone'], 'UTC');
    _grace.text = pickStr(cur, ['misfireGraceMinutes'], '60');
    _excluded
      ..clear()
      ..addAll((cur['excludedAccountIndexes'] as List? ?? []).map((e) => (e as num).toInt()));
  }

  void _pick(bool remote) {
    // bot 侧不支持远端定时时就别切过去
    if (remote && !_remoteSupported) return;
    setState(() {
      _useRemote = remote;
      _saved = null;
      _applyForm();
    });
  }

  Future<void> _save() async {
    setState(() { _busy = true; _err = null; });
    final patch = <String, dynamic>{
      'target': _onRemote ? 'remote' : 'local',
      'enabled': _cur?['enabled'] == true,
      'cron': _cron.text.trim(),
      'skipIfRunning': _cur?['skipIfRunning'] != false,
      'excludedAccountIndexes': _excluded.toList()..sort(),
    };
    if (_onRemote) {
      patch['timezone'] = _tz.text.trim().isEmpty ? 'UTC' : _tz.text.trim();
    } else {
      patch['misfirePolicy'] = pickStr(_cur, ['misfirePolicy'], 'skip');
      patch['misfireGraceMinutes'] = int.tryParse(_grace.text.trim()) ?? 60;
    }
    try {
      final r = await widget.panel.put('/api/schedule', patch);
      if (!mounted) return;
      final m = r is Map<String, dynamic> ? r : const <String, dynamic>{};
      setState(() {
        _local = m['local'] is Map ? (m['local'] as Map).cast<String, dynamic>() : _local;
        _remote = m['remote'] is Map ? (m['remote'] as Map).cast<String, dynamic>() : _remote;
        _remoteSupported = m['remoteSupported'] == true || _remoteSupported;
        _applyForm();
        _saved = '已保存（${_onRemote ? 'bot' : '面板'}）';
        _busy = false;
      });
      _toast('定时已保存，下一次运行按新计划');
    } catch (e) {
      if (mounted) setState(() { _err = '保存失败：${errText(e)}'; _busy = false; });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_local == null && _remote == null) {
      return Center(
        child: _err != null
            ? Padding(padding: const EdgeInsets.all(T.pagePad), child: ErrorBanner(_err!, onRetry: _load))
            : const LoadingBox(),
      );
    }
    final cur = _cur ?? const <String, dynamic>{};
    final enabled = cur['enabled'] == true;
    final cronErr = pickStr(cur, ['error']);
    return Scaffold(
      backgroundColor: T.canvas(context),
      appBar: AppBar(title: const Text('定时任务'), backgroundColor: T.canvas(context)),
      body: ListView(
        padding: const EdgeInsets.all(T.pagePad),
        children: [
          if (_err != null) ...[ErrorBanner(_err!, onRetry: _load), const SizedBox(height: T.gap)],
          // ---- 面板 / bot 两个后端，各存各的定时 ----
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('哪一边的定时'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _sourceCard('面板', '面板叫 bot 开跑', !_onRemote, () => _pick(false))),
                const SizedBox(width: T.gap),
                Expanded(
                  child: _sourceCard(
                    'bot',
                    _remoteSupported ? 'bot 的 cron' : '这版 bot 不支持',
                    _onRemote,
                    () => _pick(true),
                    enabled: _remoteSupported,
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: T.gap),
          PanelCard(
            child: Row(children: [
              Icon(Icons.schedule_rounded, size: 18, color: enabled ? T.green500 : T.slate400),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('启用定时', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(enabled ? '按下面的计划自动开跑' : '关闭，只能手动跑',
                      style: TextStyle(fontSize: 11, color: T.subText(context))),
                ]),
              ),
              Switch(
                value: enabled,
                activeColor: T.primary,
                onChanged: (v) => setState(() => (_cur ?? _local!)['enabled'] = v),
              ),
            ]),
          ),
          const SizedBox(height: T.gap),
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SectionTitle('计划'),
                const Spacer(),
                if (enabled && pickStr(cur, ['nextRunAt']).isNotEmpty)
                  Pill('下次 ${whenText(pickStr(cur, ['nextRunAt']))}', color: T.primary),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final p in _presets)
                  ChoiceChip(
                    label: Text(p.label, style: const TextStyle(fontSize: 11)),
                    selected: _cron.text.trim() == p.cron,
                    selectedColor: T.primaryLight,
                    shape: RoundedRectangleBorder(borderRadius: T.pill),
                    onSelected: (_) => setState(() => _cron.text = p.cron),
                  ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _cron,
                decoration: _dec('cron 表达式', '分 时 日 月 周'),
                onChanged: (_) => setState(() {}),
              ),
              if (cronErr.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(cronErr, style: TextStyle(fontSize: 11, color: T.red500))),
              if (_onRemote) ...[
                const SizedBox(height: 8),
                TextField(controller: _tz, decoration: _dec('时区', 'UTC / Asia/Shanghai')),
              ] else ...[
                const SizedBox(height: 8),
                Text('按面板所在机器的时区（当前 UTC${_tzOffsetLabel(pickInt(cur, ['timezoneOffsetMinutes']))}）',
                    style: TextStyle(fontSize: 11, color: T.subText(context))),
                const SizedBox(height: 12),
                const Text('到点时上一轮还没跑完', style: TextStyle(fontSize: 13)),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in _misfireLabels.entries)
                    ChoiceChip(
                      label: Text(e.value, style: const TextStyle(fontSize: 11)),
                      selected: pickStr(cur, ['misfirePolicy'], 'skip') == e.key,
                      selectedColor: T.primaryLight,
                      shape: RoundedRectangleBorder(borderRadius: T.pill),
                      onSelected: (_) => setState(() => (_cur ?? _local!)['misfirePolicy'] = e.key),
                    ),
                ]),
                if (pickStr(cur, ['misfirePolicy'], 'skip') == 'grace-period') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _grace,
                    keyboardType: TextInputType.number,
                    decoration: _dec('宽限（分钟）', '1 - 1440'),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('正在跑就跳过这次', style: TextStyle(fontSize: 13)),
                value: cur['skipIfRunning'] != false,
                activeColor: T.primary,
                onChanged: (v) => setState(() => (_cur ?? _local!)['skipIfRunning'] = v),
              ),
            ]),
          ),
          const SizedBox(height: T.gap),
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SectionTitle('不参与定时的账号'),
                const Spacer(),
                TextButton(onPressed: () => setState(_excluded.clear), child: const Text('全不排除', style: TextStyle(fontSize: 12))),
              ]),
              if (_accounts.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('没读到账号')),
              for (final a in _accounts)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _excluded.contains(pickInt(a, ['index'])),
                  activeColor: T.red500,
                  title: Text(pickStr(a, ['email']), style: const TextStyle(fontSize: 13)),
                  subtitle: Text('序号 ${pickInt(a, ['index'])}', style: TextStyle(fontSize: 11, color: T.subText(context))),
                  onChanged: (v) => setState(() {
                    final i = pickInt(a, ['index']);
                    if (v == true) { _excluded.add(i); } else { _excluded.remove(i); }
                  }),
                ),
            ]),
          ),
          const SizedBox(height: T.gap),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: T.primary, shape: RoundedRectangleBorder(borderRadius: T.md), padding: const EdgeInsets.symmetric(vertical: 13)),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('保存'),
              ),
            ),
            const SizedBox(width: T.gap),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新读取'),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: T.md), padding: const EdgeInsets.symmetric(vertical: 13)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(_footline(cur), style: TextStyle(fontSize: 11, height: 1.5, color: T.subText(context))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _footline(Map<String, dynamic> cur) {
    if (_onRemote) {
      final parts = <String>[
        '来源 ${pickStr(cur, ['source'])}',
        if (pickStr(cur, ['updatedAt']).isNotEmpty) '上次更新 ${pickStr(cur, ['updatedAt']).substring(0, 19)}',
        '可写 ${cur['writable'] == true ? '是' : '否'}',
      ];
      return parts.join(' · ');
    }
    final last = pickStr(cur, ['lastTriggeredAt']);
    final res = pickStr(cur, ['lastResult']);
    return [
      '面板调度器',
      if (last.isNotEmpty) '上次触发 ${whenText(last)}${res.isEmpty ? '' : '（$res）'}' else '还没触发过',
      if (_saved != null) _saved!,
    ].join(' · ');
  }

  Widget _sourceCard(String title, String sub, bool selected, VoidCallback onTap, {bool enabled = true}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? T.primaryLight : T.surface(context),
          borderRadius: T.md,
          border: Border.all(color: selected ? T.primary : T.hairline(context), width: selected ? 1.4 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 16, color: selected ? T.primary : T.slate400),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: enabled ? T.slate900 : T.slate400)),
          ]),
          const SizedBox(height: 3),
          Text(sub, style: TextStyle(fontSize: 10.5, color: T.subText(context))),
        ]),
      ),
    );
  }

  static String _tzOffsetLabel(int minutes) {
    if (minutes == 0) return '+0';
    final sign = minutes < 0 ? '-' : '+';
    final m = minutes.abs();
    final h = m ~/ 60;
    final mm = m % 60;
    return '$sign${mm == 0 ? '$h' : '$h:${mm.toString().padLeft(2, '0')}'}';
  }

  InputDecoration _dec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: T.surface(context),
        border: OutlineInputBorder(borderRadius: T.md, borderSide: BorderSide(color: T.hairline(context))),
        enabledBorder: OutlineInputBorder(borderRadius: T.md, borderSide: BorderSide(color: T.hairline(context))),
      );
}
