import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// 切页动画，和底栏胶囊共用同一条弹簧（spring dampingRatio 1 / stiffness 300），
/// 所以"胶囊甩过去"和"页面跟过来"是同一个节奏，而不是两套时间曲线。
///
/// mode：0 直接切 / 1 淡入淡出 / 2 跟随胶囊方向滑动（默认）。
///
/// 五页全部常驻元素树并始终参与布局（靠 opacity=0 不画、IgnorePointer 不接点击），
/// 不然每次切页都会把没参与动画的页的 state 抖掉 —— 日志缓冲、滚动位置、
/// 已拉到的账号数据都会重拉一遍，动画收尾那一下还会闪。
class TabSwitcher extends StatefulWidget {
  const TabSwitcher({
    super.key,
    required this.index,
    required this.mode,
    required this.speed,
    required this.children,
  });

  final int index;
  final int mode;
  final double speed;
  final List<Widget> children;

  @override
  State<TabSwitcher> createState() => _TabSwitcherState();
}

class _TabSwitcherState extends State<TabSwitcher> with SingleTickerProviderStateMixin {
  late final AnimationController _t;
  int _from = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.index;
    _t = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    _from = old.index;
    if (widget.mode == 0) {
      _t.value = 1;
      return;
    }
    // dart:math 的 max 返回 num，这里要显式收回 double
    final double k = (300 * math.max(0.3, widget.speed)).toDouble();
    _t.value = 0;
    _t.animateWith(SpringSimulation(
        SpringDescription(mass: 1, stiffness: k, damping: 2 * math.sqrt(k)), 0, 1, 0));
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.children.length;
    final width = MediaQuery.sizeOf(context).width;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final t = _t.value.clamp(0.0, 1.2).toDouble();
        final done = t > 0.995;
        final dir = widget.index >= _from ? 1.0 : -1.0;
        // 1 - (1-t)^3：起步快、收尾稳，和胶囊的临界阻尼读起来一致
        final e = 1 - math.pow(1 - math.min(1.0, t), 3).toDouble();

        // 每一页拿到的包装链必须**完全一样**（IgnorePointer > translate > scale > opacity），
        // 静止和动画中只有数值不同。之前按分支返回不同形状的 widget，动画收尾时
        // 那个位置的 widget 类型从 Transform 变成 Offstage，Element 整棵子树被重建 ——
        // 页面的 State 直接丢掉、initState 重跑，现象就是"切完页闪一下"、滚动位置也没了。
        Widget child(int i) {
          double dx = 0, scale = 1, opacity = 0;
          if (done) {
            if (i == widget.index) opacity = 1;
          } else if (i == widget.index) {
            // 新页：从胶囊行进方向的另一侧进来，带一点视差与微缩放
            dx = dir * (1 - e) * width * 0.16;
            scale = 0.985 + 0.015 * e;
            opacity = widget.mode == 1 ? e.clamp(0.0, 1.0).toDouble() : 1;
          } else if (i == _from) {
            dx = -dir * e * width * 0.07;
            scale = 1 - 0.015 * e;
            opacity = (1 - e).clamp(0.0, 1.0).toDouble();
          }
          return IgnorePointer(
            ignoring: opacity <= 0.001,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.scale(
                scale: scale,
                child: Opacity(opacity: opacity, child: widget.children[i]),
              ),
            ),
          );
        }

        return Stack(children: [for (var i = 0; i < count; i++) Positioned.fill(child: child(i))]);
      },
    );
  }
}
