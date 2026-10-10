import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/panel.dart';
import '../core/settings.dart';
import '../core/tokens.dart';
import '../core/util.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('面板地址不能空着，否则哪儿也连不上')));
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
            : '面板说不可达：${s['lastError'] ?? '未知'}',
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
      results.add((name: '接管视图', result: '没填视图 token（可选项，不填就没有"视图"页）', ok: true));
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
      padding: const EdgeInsets.all(T.pagePad),
      children: [
        PanelCard(
          padding: const EdgeInsets.symmetric(horizontal: T.gap, vertical: 4),
          child: Column(children: [
            const SizedBox(height: 8),
            const SectionTitle('功能'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded, size: 20, color: T.primary),
              title: const Text('定时跑', style: TextStyle(fontSize: 14)),
              subtitle: const Text('面板 / bot 两边各自的 cron、哪些账号不参与', style: TextStyle(fontSize: 11)),
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
            Text('只填面板地址。Control API 的地址和 token 都存在面板那边，App 里不再要第二份。',
                style: TextStyle(fontSize: 11, height: 1.5, color: T.subText(context))),
            const SizedBox(height: 10),
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
                  ? '接管视图地址：填好面板地址后自动按 http://<面板主机>:8891 拼'
                  : '接管视图地址（自动）：${Settings.viewBase}',
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
            Text('Rewards 手机端的原生客户端，视觉沿用呆呆面板 APP 的设计令牌：主色 #409EFF、slate 灰阶、圆角 8/12/14/pill、五页底部导航。\n\n'
                '· 主页：实时状态、启停、近 7 天趋势\n'
                '· 账号：当前积分 / 本次获得 / 连胜，常驻批量运行 + 下次自动运行时间\n'
                '· 日志：bot 的滚动日志，可按级别过滤\n'
                '· 视图：无头浏览器的 MJPEG 画面，点哪打哪（需单独填视图 token）\n'
                '· 更多：面板地址、连通性自检\n\n'
                '所有请求都打到面板一个地址：读走面板的 sqlite，启停/参数/定时经面板的 /api/control、/api/config、/api/schedule 代理，'
                '所以 App 里不需要 bot 的 token。',
                style: TextStyle(fontSize: 12, height: 1.6, color: T.subText(context))),
          ]),
        ),
        const SizedBox(height: T.gap),
      ],
    );
  }
}
