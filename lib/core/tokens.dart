import 'package:flutter/material.dart';

/// 视觉令牌，1:1 取自 Dumb-Panel-APP 的 design_tokens.dart / app_theme.dart：
/// 主色对齐 Element Plus 的 #409EFF，灰阶用 slate，圆角只有 sm/md/lg/pill 四档。
class T {
  T._();

  static const Color primary = Color(0xFF409EFF);
  static const Color primaryLight = Color(0xFFECF5FF);
  static const Color primaryDark = Color(0xFF337ECC);

  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF020617);

  static const Color green500 = Color(0xFF22C55E);
  static const Color green100 = Color(0xFFDCFCE7);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color red500 = Color(0xFFEF4444);
  static const Color red100 = Color(0xFFFEE2E2);
  static const Color purple500 = Color(0xFF8B5CF6);
  static const Color purple100 = Color(0xFFEDE9FE);

  /// 圆角四档，没有第五个
  static const double rSm = 8;
  static const double rMd = 12;
  static const double rLg = 14;
  static const double rPill = 999;

  static const double gap = 12;
  static const double pagePad = 16;

  static BorderRadius get sm => BorderRadius.circular(rSm);
  static BorderRadius get md => BorderRadius.circular(rMd);
  static BorderRadius get lg => BorderRadius.circular(rLg);
  static BorderRadius get pill => BorderRadius.circular(rPill);

  /// 卡片表面：浅色 slate50 底上的白卡，深色 slate900 底上的 slate800 卡
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? slate800 : Colors.white;

  static Color canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? slate900 : slate100;

  static Color subText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? slate400 : slate500;

  static Color hairline(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? slate700 : slate200;
}
