import 'package:flutter/material.dart';

import 'core/panel.dart';
import 'core/settings.dart';
import 'core/tokens.dart';
import 'pages/accounts.dart';
import 'pages/home.dart';
import 'pages/logs.dart';
import 'pages/more.dart';
import 'pages/setup.dart';
import 'widgets/glass_dock.dart';
import 'pages/view.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.onChanged});
  final VoidCallback? onChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  /// 整个 App 只有一个后端入口：面板。token 都留在面板那边。
  Panel get _panel => Panel(base: Settings.panelBase, user: Settings.panelUser, pass: Settings.panelPass);

  @override
  Widget build(BuildContext context) {
    if (!Settings.hasPanel) {
      return SetupPage(onDone: () {
        setState(() {});
        widget.onChanged?.call();
      });
    }
    final pages = [
      HomePage(panel: _panel),
      AccountsPage(panel: _panel),
      LogsPage(panel: _panel),
      ViewPage(base: Settings.viewBase, token: Settings.viewToken),
      MorePage(panel: _panel, onChanged: () {
        setState(() {});
        widget.onChanged?.call();
      }),
    ];
    return Scaffold(
      backgroundColor: T.canvas(context),
      appBar: AppBar(
        backgroundColor: T.canvas(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: T.primary, borderRadius: T.sm),
            child: const Icon(Icons.redeem_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Text('Rewards', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ]),
      ),
      body: Stack(children: [
        Positioned.fill(child: IndexedStack(index: _tab, children: pages)),
        // 悬浮：内容要从它下面滚过去，BackdropFilter 才糊得出东西来。
        // 用 bottomNavigationBar 的话系统会把内容顶在上面，玻璃变成一块不透明灰条。
        Positioned(left: 0, right: 0, bottom: 0, child: _dock(context)),
      ]),
    );
  }

  Widget _dock(BuildContext context) {
    return GlassDock(
      index: _tab,
      onSelect: (i) => setState(() => _tab = i),
      items: const [
        DockItem(icon: Icons.space_dashboard_outlined, activeIcon: Icons.space_dashboard_rounded, label: '主页'),
        DockItem(icon: Icons.people_outline, activeIcon: Icons.people_rounded, label: '账号'),
        DockItem(icon: Icons.terminal_outlined, activeIcon: Icons.terminal_rounded, label: '日志'),
        DockItem(icon: Icons.visibility_outlined, activeIcon: Icons.visibility_rounded, label: '视图'),
        DockItem(icon: Icons.menu_outlined, activeIcon: Icons.menu_rounded, label: '更多'),
      ],
    );
  }
}
