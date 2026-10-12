import 'package:flutter/material.dart';

import '../core/panel.dart';
import '../core/settings.dart';
import '../core/tokens.dart';
import '../widgets/ui.dart';

/// 第一次打开（没填面板地址）就停在这一页：只问一个地址，其余参数运行时从面板取。
class SetupPage extends StatefulWidget {
  const SetupPage({super.key, this.onDone});
  final VoidCallback? onDone;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _base = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _showAuth = false;
  bool _busy = false;
  String? _err;
  String? _okLine;

  @override
  void dispose() {
    _base.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _save() {
    final url = _base.text.trim();
    if (url.isEmpty) {
      setState(() => _err = '先填面板地址');
      return;
    }
    Settings.panelBase = url;
    Settings.panelUser = _user.text.trim();
    Settings.panelPass = _pass.text;
    setState(() {
      _err = null;
      _okLine = '已保存 · ${Settings.panelBase}';
    });
    widget.onDone?.call();
  }

  Future<void> _probe() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final p = Panel(base: _base.text.trim(), user: _user.text.trim(), pass: _pass.text);
      final d = await p.get('/api/health');
      final m = d is Map ? d : const <dynamic, dynamic>{};
      setState(() {
        _okLine = m['ok'] == true
            ? '面板在线 · bot 可达=${m['controlApi']} · 事件流=${m['streamConnected']}'
            : '面板回了话但 ok!=true：$d';
      });
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    return Scaffold(
      backgroundColor: T.canvas(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(T.pagePad * 1.5),
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: T.primary, borderRadius: T.md),
              child: const Icon(Icons.redeem_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 14),
            const Text('连上你的 Rewards 面板', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('只填面板地址；定时、参数、启停都经面板代理。',
                style: TextStyle(fontSize: 12.5, height: 1.6, color: T.subText(context))),
            const SizedBox(height: 18),
            PanelCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  key: const ValueKey('setup-base'),
                  controller: _base,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: _dec('面板地址', 'http://192.168.1.4:8890'),
                  onChanged: (_) => setState(() => _err = null),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _showAuth = !_showAuth),
                  icon: Icon(_showAuth ? Icons.expand_less : Icons.expand_more, size: 18),
                  label: Text(_showAuth ? '收起鉴权' : '面板开了鉴权才填', style: const TextStyle(fontSize: 12)),
                ),
                if (_showAuth)
                  Column(children: [
                    Row(children: [
                      Expanded(child: TextField(controller: _user, decoration: _dec('用户', ''))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _pass, decoration: _dec('密码', ''), obscureText: true)),
                    ]),
                    const SizedBox(height: 4),
                  ]),
                const SizedBox(height: 10),
                if (_err != null) ...[ErrorBanner(_err!, onRetry: _probe), const SizedBox(height: T.gap)],
                if (_okLine != null) ...[
                  Text(_okLine!, style: TextStyle(fontSize: 12, color: T.green500)),
                  const SizedBox(height: 10),
                ],
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('setup-save'),
                      style: FilledButton.styleFrom(
                          backgroundColor: T.primary,
                          shape: RoundedRectangleBorder(borderRadius: T.md),
                          padding: const EdgeInsets.symmetric(vertical: 13)),
                      onPressed: _save,
                      child: const Text('保存并进入'),
                    ),
                  ),
                  const SizedBox(width: T.gap),
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('setup-probe'),
                      style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: T.md),
                          padding: const EdgeInsets.symmetric(vertical: 13)),
                      onPressed: _busy ? null : _probe,
                      child: Text(_busy ? '自检中…' : '先测一下'),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            Text('同一台手机上时填局域网 IP，别填 127.0.0.1；面板默认端口 8890。',
                style: TextStyle(fontSize: 11.5, height: 1.6, color: T.subText(context))),
          ],
        ),
      ),
    );
  }
}
