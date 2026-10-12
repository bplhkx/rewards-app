import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../core/util.dart';

/// 与面板 charts.js 的 heatmapLevel 同一套分档：按该账号自己的日均分（只算有分的日子），
/// 而不是固定阈值或最高分 —— 否则一次补分的大晴天会把普通日子全冲成"没跑"。
int heatLevel(int gained, double avg) {
  if (gained <= 0) return 0;
  final ratio = gained / avg;
  if (ratio < 0.6) return 1;
  if (ratio < 1.1) return 2;
  if (ratio < 1.75) return 3;
  return 4;
}

/// 面板是 `--accent` 与 `--surface` 按 30/55/80/100% 混合，0 档用淡描边色
Color heatColor(BuildContext context, int level) {
  if (level == 0) return T.hairline(context).withValues(alpha: 0.35);
  const mix = [0.0, 0.30, 0.55, 0.80, 1.0];
  return Color.lerp(T.surface(context), T.primary, mix[level])!;
}

/// 该账号自己的日均分（只算有分的日子）；没记录时给 1 避免除零。
double heatAvg(Map<String, int> byDay) {
  final gains = byDay.values.where((v) => v > 0).toList();
  if (gains.isEmpty) return 1;
  return gains.reduce((a, b) => a + b) / gains.length;
}

/// 每日积分热力图：面板"账户概况"那张 GitHub 式网格的手机版。
///
/// 行=周一到周日、列=周，语义与面板一致；差别只在窗口 —— 面板铺 53 周，
/// 手机只给 12 周，再宽格子就小到点不准了。
class DailyHeatmap extends StatelessWidget {
  const DailyHeatmap({super.key, required this.byDay, this.weeks = 12, this.onTapDay});

  /// 键是本地日期 "YYYY-MM-DD"，值是当天获得的积分
  final Map<String, int> byDay;
  final int weeks;
  final void Function(String key, int gained)? onTapDay;

  static const double _cell = 16;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // 窗口 = 以今天所在的那一周为最后一列，往回共 weeks 周，再对齐到周一。
    // DateTime 是不可变值类型，必须普通赋值 —— 级联 `..subtract()` 会把接收者原样返回，
    // 窗口就永远停在"从今天往未来"排。
    final thisMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final start = thisMonday.subtract(Duration(days: (weeks - 1) * 7));
    final avg = heatAvg(byDay);
    final monthLabels = <int, String>{};
    var lastMonth = -1;
    for (var w = 0; w < weeks; w++) {
      final m = start.add(Duration(days: w * 7)).month;
      if (m != lastMonth) {
        monthLabels[w] = '$m月';
        lastMonth = m;
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _WeekdayLabels(cellBlock: _cell + _gap, fontSize: 8),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var w = 0; w < weeks; w++)
              Expanded(
                child: Column(children: [
                  for (var d = 0; d < 7; d++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: _gap),
                      child: HeatCell(
                        day: start.add(Duration(days: w * 7 + d)),
                        size: _cell,
                        byDay: byDay,
                        avg: avg,
                        onTapDay: onTapDay,
                      ),
                    ),
                ]),
              ),
          ]),
        ),
      ]),
      const SizedBox(height: 2),
      Padding(
        padding: const EdgeInsets.only(left: 16),
        child: LayoutBuilder(builder: (context, box) {
          final colW = box.maxWidth / weeks;
          return SizedBox(
            height: 12,
            child: Stack(children: [
              for (final e in monthLabels.entries)
                Positioned(left: e.key * colW, child: Text(e.value, style: TextStyle(fontSize: 9, color: T.slate400))),
            ]),
          );
        }),
      ),
      const SizedBox(height: 4),
      Row(children: [
        Text('少', style: TextStyle(fontSize: 9, color: T.slate400)),
        const SizedBox(width: 4),
        for (var l = 0; l <= 4; l++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: heatColor(context, l)),
            ),
          ),
        const SizedBox(width: 4),
        Text('多', style: TextStyle(fontSize: 9, color: T.slate400)),
        const Spacer(),
        Text('${byDay.length} 天有记录', style: TextStyle(fontSize: 9, color: T.slate400)),
      ]),
    ]);
  }
}

/// 当月热力图：紧凑卡片用的迷你版。行仍是周一到周日，列只覆盖本月那几周；
/// 月外的格子画成透明占位以保持对齐，未来淡显、今天描边。
class MonthHeatmap extends StatelessWidget {
  const MonthHeatmap({super.key, required this.byDay, this.cell = 11, this.gap = 2, this.onTapDay});

  final Map<String, int> byDay;
  final double cell;
  final double gap;
  final void Function(String key, int gained)? onTapDay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final weeks = ((lastDay + first.weekday - 1) / 7).ceil();
    // 一次性把日期算完，别在 build 子树里边画边推进游标（重建会跑偏）
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final avg = heatAvg(byDay);
    final prefix = '${now.year}-${two(now.month)}';
    final monthTotal = byDay.entries
        .where((e) => e.key.startsWith(prefix))
        .fold<int>(0, (s, e) => s + e.value);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _WeekdayLabels(cellBlock: cell + gap, fontSize: 7, width: 12),
        const SizedBox(width: 2),
        for (var w = 0; w < weeks; w++)
          Column(children: [
            for (var d = 0; d < 7; d++)
              Padding(
                padding: EdgeInsets.only(bottom: gap),
                child: HeatCell(
                  day: gridStart.add(Duration(days: w * 7 + d)),
                  size: cell,
                  radius: 2,
                  onlyMonth: now.month,
                  byDay: byDay,
                  avg: avg,
                  onTapDay: onTapDay,
                ),
              ),
          ]),
      ]),
      const SizedBox(height: 2),
      Text('${now.month} 月 · 本月 +$monthTotal', style: TextStyle(fontSize: 9, color: T.subText(context))),
    ]);
  }
}

/// 周一/三/五的行标（第 0 行就是周一）
class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels({required this.cellBlock, required this.fontSize, this.width = 16});
  final double cellBlock;
  final double fontSize;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(children: [
          for (var d = 0; d < 7; d++)
            SizedBox(
              height: cellBlock,
              child: Text(const ['一', '', '三', '', '五', '', ''][d],
                  style: TextStyle(fontSize: fontSize, color: T.slate400)),
            ),
        ]),
      );
}

/// 一个格子：月外日期透明占位，未来淡显不可点，今天描边。
class HeatCell extends StatelessWidget {
  const HeatCell({super.key, required this.day,
    required this.size,
    required this.byDay,
    required this.avg,
    this.radius = 3,
    this.onlyMonth,
    this.onTapDay,
  });

  final DateTime day;
  final double size;
  final double radius;
  final int? onlyMonth;
  final Map<String, int> byDay;
  final double avg;
  final void Function(String key, int gained)? onTapDay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final inWindow = onlyMonth == null || day.month == onlyMonth;
    final key = dayKey(day);
    final future = DateTime(day.year, day.month, day.day).isAfter(DateTime(now.year, now.month, now.day));
    final gained = byDay[key] ?? 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (!inWindow || future) ? null : () => onTapDay?.call(key, gained),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: !inWindow
              ? Colors.transparent
              : future
                  ? T.hairline(context).withValues(alpha: 0.18)
                  : heatColor(context, heatLevel(gained, avg)),
          border: key == dayKey(now) ? Border.all(color: T.slate700, width: 1) : null,
        ),
      ),
    );
  }
}
