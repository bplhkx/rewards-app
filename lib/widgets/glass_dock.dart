import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// 底部 dock 的一个入口。
class DockItem {
  const DockItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// 类苹果的悬浮玻璃 dock。
///
/// 抄的是 KernelSU 管理器里那套（`ui/component/FloatingBottomBar.kt` + Miuix 的
/// `top.yukonga.miuix.kmp:miuix-blur`，它同时提供了 Material 和 Miuix 两种皮肤，
/// 悬浮玻璃是 Miuix 那条分支）。Compose 库在 Flutter 里用不了，所以照它的参数复刻：
/// 左右各留 28、底部 8 + 系统导航条高度（没有导航条时 28）、条目最小宽 76、
/// 图标下 1dp 间距接 11sp 文字、选中项是一块半透明圆角胶囊、外圈 1dp 高光描边。
///
/// 玻璃感靠 BackdropFilter 真实模糊 body 的内容 —— 注意必须让页面内容真的从它下面
/// 滚过去才看得出模糊，所以 app_shell 用的是 Stack 而不是 bottomNavigationBar。
class GlassDock extends StatelessWidget {
  const GlassDock({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
    this.blur = 20,
  });

  final List<DockItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  final double blur;

  /// 页面给底部留白的参考值：胶囊本体 + 悬浮间距 + 系统手势条。
  static double reserve(BuildContext context) {
    final inset = MediaQuery.of(context).padding.bottom;
    return 74 + (inset > 0 ? inset : 20);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inset = MediaQuery.of(context).padding.bottom;
    final bottom = inset > 0 ? 8.0 + inset : 28.0;
    final radius = BorderRadius.circular(26);

    return Padding(
      padding: EdgeInsets.fromLTRB(28, 0, 28, bottom),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // 半透明底 + 真实模糊：只留 alpha 不模糊就变成"灰条"，不是玻璃。
              // 透明度压到 0.5 左右才看得出后面滚过的内容，再低就没法点了。
              color: dark ? const Color(0xFF1C1C1E).withValues(alpha: 0.50) : Colors.white.withValues(alpha: 0.48),
              borderRadius: radius,
              border: Border.all(
                color: dark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.85),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.40 : 0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                // 上亮下暗的一层高光，苹果那圈"边缘反光"主要靠它
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.02)]
                      : [Colors.white.withValues(alpha: 0.42), Colors.white.withValues(alpha: 0.10)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Row(children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(child: _item(context, i, items[i], dark)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i, DockItem it, bool dark) {
    final selected = i == index;
    final tint = selected ? T.primary : (dark ? Colors.white70 : T.slate500);
    return InkWell(
      borderRadius: BorderRadius.circular(21),
      onTap: () => onSelect(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? T.primary.withValues(alpha: dark ? 0.22 : 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(selected ? it.activeIcon : it.icon, size: 21, color: tint),
          const SizedBox(height: 1),
          Text(
            it.label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: 11,
              height: 14 / 11,
              color: tint,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ]),
      ),
    );
  }
}
