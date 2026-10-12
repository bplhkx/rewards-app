import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/panel.dart';
import '../core/settings.dart';
import '../core/tokens.dart';
import '../core/util.dart';
import '../widgets/glass_dock.dart';
import '../widgets/ui.dart';
import 'config_page.dart';
import 'schedule.dart';

class MorePage extends StatefulWidget {
  const MorePage({super.key, required this.panel, this.onChanged});
  final Panel panel;
  final VoidCallback? onChanged;

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  // 全部默认空：不编 IP、不编 token，填了才存
  late final TextEditingController _panelBase = TextEditingController(text: Settings.panelBase);
  late final TextEditingController _panelUser = TextEditingController(text: Settings.panelUser);
  late final TextEditingController _panelPass = TextEditingController(text: Settings.panelPass);
  late final TextEditingController _viewToken = TextEditingController(text: Settings.viewToken);

  final List<({String name, String result, bool ok})> _probe = [];

  @override
  void dispose() {
    for (final c in [_panelBase, _panelUser, _panelPass, _viewToken]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _save() {
    final url = _panelBase.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('面板地址不能空')));
      return false;
    }
    Settings.panelBase = url;
    Settings.panelUser = _panelUser.text.trim();
    Settings.panelPass = _panelPass.text;
    Settings.viewToken = _viewToken.text.trim();
    widget.onChanged?.call();
    return true;
  }

  Future<void> _probeAll() async {
    if (!_save()) return;
    setState(() {
      _probe.clear();
      _probe.add((name: '探测中…', result: '', ok: true));
    });
    final results = <({String name, String result, bool ok})>[];
    final p = Panel(base: Settings.panelBase, user: Settings.panelUser, pass: Settings.panelPass);

    try {
      final d = await p.get('/api/health');
      final m = d is Map ? d : const <dynamic, dynamic>{};
      results.add((
        name: '面板',
        result: 'ok · bot 可达=${m['controlApi']} · 事件流=${m['streamConnected']}',
        ok: m['ok'] == true
      ));
    } catch (e) {
      results.add((name: '面板', result: errText(e), ok: false));
    }

    // bot 的状态也是从面板拿的（面板自己持有 Control API 的 token）
    try {
      final d = await p.get('/api/summary');
      final s = (d is Map && d['status'] is Map) ? (d['status'] as Map) : const <dynamic, dynamic>{};
      results.add((
        name: 'bot（经面板）',
        result: s['reachable'] == true
            ? 'v${s['version']} · ${s['botState']} · 已连 ${minutes(s['uptimeSec'] is num ? s['uptimeSec'] as num : 0)} 分钟'
            : '不可达：${s['lastError'] ?? '未知'}',
        ok: s['reachable'] == true
      ));
    } catch (e) {
      results.add((name: 'bot（经面板）', result: errText(e), ok: false));
    }

    if (Settings.hasView) {
      try {
        final v = Api(base: Settings.viewBase, token: Settings.viewToken);
        final d = await v.get('/status');
        final m = d is Map ? d : const <dynamic, dynamic>{};
        results.add((
          name: '接管视图',
          result: m['active'] == true ? '画面在线 · 帧 ${m['frames']}' : '服务在，等 bot 起浏览器',
          ok: true
        ));
      } catch (e) {
        results.add((name: '接管视图', result: errText(e), ok: false));
      }
    } else {
      results.add((name: '接管视图', result: '未填视图 token（可选）', ok: true));
    }

    if (!mounted) return;
    setState(() {
      _probe
        ..clear()
        ..addAll(results);
    });
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(T.pagePad, T.pagePad, T.pagePad, GlassDock.reserve(context) + T.gap),
      children: [
        PanelCard(
          padding: const EdgeInsets.symmetric(horizontal: T.gap, vertical: 4),
          child: Column(children: [
            const SizedBox(height: 8),
            const SectionTitle('功能'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded, size: 20, color: T.primary),
              title: const Text('定时任务', style: TextStyle(fontSize: 14)),
              subtitle: const Text('面板 / bot 各自的 cron、排除账号', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SchedulePage(panel: widget.panel))),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune_rounded, size: 20, color: T.purple500),
              title: const Text('参数设置', style: TextStyle(fontSize: 14)),
              subtitle: const Text('执行开关、等待节奏、搜索策略、appkey', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConfigPage(panel: widget.panel))),
            ),
            const SizedBox(height: 8),
          ]),
        ),
        const SizedBox(height: T.gap),
        PanelCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('地址与凭据'),
            const SizedBox(height: 6),
            TextField(key: const ValueKey("field-panelBase"), controller: _panelBase, keyboardType: TextInputType.url,
                decoration: _dec('面板地址', 'http://192.168.1.4:8890')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(key: const ValueKey("field-panelUser"), controller: _panelUser, decoration: _dec('面板用户', '没开鉴权就留空'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _panelPass, decoration: _dec('面板密码', '没开就留空'), obscureText: true)),
            ]),
            const SizedBox(height: 8),
            TextField(key: const ValueKey("field-viewToken"), controller: _viewToken, decoration: _dec('视图 token（可选）', '接管服务的 TAKEOVER_TOKEN'), obscureText: true),
            const SizedBox(height: 6),
            Text(
              Settings.host.isEmpty
                  ? '视图地址：按面板主机自动拼 :8891'
                  : '视图地址（自动）：${Settings.viewBase}',
              style: TextStyle(fontSize: 11, color: T.subText(context)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey("btn-save"),
                  style: FilledButton.styleFrom(backgroundColor: T.primary, shape: RoundedRectangleBorder(borderRadius: T.md), padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () {
                    if (_save()) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
                  },
                  child: const Text('保存'),
                ),
              ),
              const SizedBox(width: T.gap),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey("btn-probe"),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: T.md), padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _probeAll,
                  child: const Text('连通性自检'),
                ),
              ),
            ]),
          ]),
        ),
        if (_probe.isNotEmpty) ...[
          const SizedBox(height: T.gap),
          PanelCard(
            padding: const EdgeInsets.symmetric(horizontal: T.gap, vertical: 4),
            child: Column(children: [
              const SizedBox(height: 8),
              const SectionTitle('自检结果'),
              ..._probe.map((r) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(r.ok ? Icons.check_circle : Icons.cancel, size: 18, color: r.ok ? T.green500 : T.red500),
                    title: Text(r.name, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(r.result, style: const TextStyle(fontSize: 11)),
                  )),
              const SizedBox(height: 8),
            ]),
          ),
        ],
        const SizedBox(height: T.gap),
        PanelCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('深色模式', style: TextStyle(fontSize: 14)),
            value: Settings.dark,
            activeColor: T.primary,
            onChanged: (v) => setState(() => Settings.dark = v),
          ),
        ),
        const SizedBox(height: T.gap),
        PanelCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('关于'),
            const SizedBox(height: 8),
            Text('Rewards 手机端原生客户端。所有请求只打面板一个地址，App 不持有 bot 的 token。',
                style: TextStyle(fontSize: 12, height: 1.6, color: T.subText(context))),
          ]),
        ),
        const SizedBox(height: T.gap),
      ],
    );
  }
}
