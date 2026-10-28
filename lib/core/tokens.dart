import 'package:flutter/material.dart';

import 'style.dart';

/// 视觉令牌，1:1 取自 Dumb-Panel-APP 的 design_tokens.dart / app_theme.dart：
/// 灰阶用 slate，圆角只有 sm/md/lg/pill 四档。
class T {
  T._();

  /// 面板蓝：个性化页没动过主题色时就是它
  static const Color blue = Color(0xFF409EFF);

  /// 主色三档全部跟着个性化页走，所以是 getter 不是 const。
  /// 注意：因此 `const TextStyle(color: T.primary)` 会编译不过，
  /// 用到主色的地方必须去掉 const（个性化生效的前提）。
  static Color get primary => StyleStore.I.accent;
  static Color get primaryLight => StyleStore.I.accentLight;
  static Color get primaryDark => StyleStore.I.accentDark;

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
  static const Color cyan500 = Color(0xFF06B6D4);
  static const Color cyan100 = Color(0xFFCFFAFE);

  // ---------- 活动固定色 ----------
  //
  // 同一个活动在账号卡的胶囊、详情页的「打卡情况」和「升级活动打卡进度」里
  // 必须是同一个色，所以下面这些界面一律从这里取，不要就地写 T.purple500。
  // 之前打架的地方：绿色既是"今日已拿到分"（状态）又是"每日活动"（活动），
  // 紫色既是"必应 App"（活动）又是账号卡上的"默认搜索"胶囊。
  //
  // 活动：          色：
  //  印章收集        主色（跟个性化页的主题色走）
  //  必应搜索        主色
  //  每日打卡        主色
  //  今日搜索额度    主色
  //  必应 App        紫   —— 打卡情况和升级活动两处同一个紫
  //  默认搜索引擎    青   —— 账号卡胶囊和升级活动行同一个青
  //  每日活动        绿
  //
  // 绿/红/灰只当状态色用（拿到分 / 失败 / 未记录），不当活动色。
  static Color get actPunch => primary;
  static Color get actSearch => primary;
  static Color get actDailySet => primary;
  static Color get actSearchQuota => primary;
  static Color get actBingApp => purple500;
  static Color get actDefaultSearch => cyan500;
  static Color get actDailyActivity => green500;

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
