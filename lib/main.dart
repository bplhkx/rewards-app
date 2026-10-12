import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'core/settings.dart';
import 'core/style.dart';
import 'core/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.init();
  await StyleStore.I.load();
  runApp(const RewardsApp());
}

class RewardsApp extends StatefulWidget {
  const RewardsApp({super.key});

  @override
  State<RewardsApp> createState() => _RewardsAppState();
}

class _RewardsAppState extends State<RewardsApp> {
  // 改完设置（含深色开关）从根节点重建一次，主题才会跟着换
  void _restart() => setState(() {});

  @override
  void initState() {
    super.initState();
    // 个性化页改主题色要立刻反映到 seed color，不然按钮/滑块还是老的
    StyleStore.I.addListener(_restart);
  }

  @override
  void dispose() {
    StyleStore.I.removeListener(_restart);
    super.dispose();
  }

  ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: StyleStore.I.accent, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? T.slate900 : T.slate100,
      textTheme: Typography.blackCupertino.apply(
        bodyColor: dark ? T.slate100 : T.slate900,
        displayColor: dark ? Colors.white : T.slate900,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? T.slate900 : T.slate100,
        foregroundColor: dark ? Colors.white : T.slate900,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerColor: dark ? T.slate700 : T.slate200,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rewards',
      debugShowCheckedModeBanner: false,
      themeMode: Settings.dark ? ThemeMode.dark : ThemeMode.light,
      theme: _build(Brightness.light),
      darkTheme: _build(Brightness.dark),
      // 没填面板地址时 AppShell 自己会停在引导页，不用额外的 gate
      home: AppShell(onChanged: _restart),
    );
  }
}
