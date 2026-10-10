import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// 每日获得积分柱状图。手写 CustomPainter，不引图表库：参考实现的趋势图也是扁平细柱。
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.days, this.height = 120});

  /// (标签, 数值)，按时间升序
  final List<({String label, int value})> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return SizedBox(
          height: height,
          child: Center(
              child: Text('还没有数据', style: TextStyle(fontSize: 12, color: T.subText(context)))));
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _Bars(days: days, dark: Theme.of(context).brightness == Brightness.dark),
        size: Size.infinite,
      ),
    );
  }
}

class _Bars extends CustomPainter {
  _Bars({required this.days, required this.dark});
  final List<({String label, int value})> days;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = days.map((d) => d.value).fold<int>(1, (a, b) => a > b ? a : b);
    final n = days.length;
    final slot = size.width / n;
    final barW = slot * 0.46;
    final labelH = 16.0;
    final chartH = size.height - labelH - 14; // 顶部留数值位

    final bar = Paint()..color = T.primary;
    final barZero = Paint()..color = dark ? T.slate700 : T.slate200;
    final text = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (var i = 0; i < n; i++) {
      final d = days[i];
      final h = d.value <= 0 ? 3.0 : (d.value / maxV) * chartH;
      final x = i * slot + (slot - barW) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartH + 6 - h, barW, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, d.value <= 0 ? barZero : bar);

      text.text = TextSpan(
        text: d.value > 0 ? '+${d.value}' : '',
        style: TextStyle(fontSize: 9, color: dark ? T.slate300 : T.slate600, fontWeight: FontWeight.w600),
      );
      text.layout();
      text.paint(canvas, Offset(x + (barW - text.width) / 2, chartH + 6 - h - 12));

      text.text = TextSpan(
        text: d.label,
        style: TextStyle(fontSize: 9, color: dark ? T.slate400 : T.slate500),
      );
      text.layout();
      text.paint(canvas, Offset(x + (barW - text.width) / 2, chartH + 10));
    }
  }

  @override
  bool shouldRepaint(_Bars old) => old.days != days || old.dark != dark;
}
