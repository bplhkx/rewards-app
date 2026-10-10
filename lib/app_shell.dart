import 'package:flutter/material.dart';

import 'core/panel.dart';
import 'core/settings.dart';
import 'core/tokens.dart';
import 'pages/accounts.dart';
import 'pages/home.dart';
import 'pages/logs.dart';
import 'pages/more.dart';
import 'pages/setup.dart';
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
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: T.surface(context),
        indicatorColor: T.primaryLight,
        selectedIndex: _tab,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: '主页'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: '账号'),
          NavigationDestination(icon: Icon(Icons.terminal_outlined), selectedIcon: Icon(Icons.terminal_rounded), label: '日志'),
          NavigationDestination(icon: Icon(Icons.visibility_outlined), selectedIcon: Icon(Icons.visibility_rounded), label: '视图'),
          NavigationDestination(icon: Icon(Icons.menu_outlined), selectedIcon: Icon(Icons.menu_rounded), label: '更多'),
        ],
      ),
    );
  }
}
