import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'core/settings.dart';
import 'core/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.init();
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

  ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: T.primary, brightness: brightness);
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? T.slate800 : Colors.white,
        indicatorColor: dark ? T.primary.withValues(alpha: 0.22) : T.primaryLight,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dark ? T.slate300 : T.slate600)),
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
