import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// 扁平卡片：参考实现里 96% 的"卡片"不走 Material Card，就是圆角容器 + 描边。
class PanelCard extends StatelessWidget {
  const PanelCard({super.key, required this.child, this.padding, this.onTap, this.accent});

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  /// accent 非空 = 这条正是 bot 当前在跑的账号：边框换成主色并铺一点底色。
  /// 只靠一个小 pill 的话，手机上一屏四个账号扫过去根本分不出来。
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: T.surface(context),
      borderRadius: T.lg,
      child: InkWell(
        borderRadius: T.lg,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: T.lg,
            color: accent?.withValues(alpha: dark ? 0.14 : 0.06),
            border: Border.all(color: accent ?? T.hairline(context), width: accent == null ? 1 : 1.6),
          ),
          padding: padding ?? const EdgeInsets.all(T.gap),
          child: child,
        ),
      ),
    );
  }
}

/// 一排小格子表示"最近 N 天有没有打卡"：填了色的那天有分，空心是没跑/没拿分。
/// 连续天数光写个数字看不出趋势，这种点阵一眼就能看出哪几天断了。
class StreakDots extends StatelessWidget {
  const StreakDots({super.key, required this.days, this.color = T.primary, this.cell = 12});

  /// 从最近一天往前排（与 [days] 的顺序一致：下标 0 = 今天）
  final List<bool> days;
  final Color color;
  final double cell;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (var i = 0; i < days.length; i++)
          Container(
            width: cell,
            height: cell,
            decoration: BoxDecoration(
              color: days[i] ? color : Colors.transparent,
              border: Border.all(color: days[i] ? color : T.hairline(context)),
              borderRadius: BorderRadius.circular(cell * 0.28),
            ),
          ),
      ],
    );
  }
}

/// 一条进度：左边名字，右边数值，下面用方格表示进度或最近 N 天。
/// 一律只用方格 —— 条状进度在手机上看不出刻度，"14 天里的第 3 天"数格子比看色带快。
class ProgressRow extends StatelessWidget {
  const ProgressRow({
    super.key,
    required this.label,
    this.value,
    this.dots,
    this.note,
    this.color = T.primary,
    this.dotCell = 12,
  });

  final String label;
  final String? value;

  /// 方格：true = 这一格已完成/当天有分
  final List<bool>? dots;
  final String? note;
  final Color color;
  final double dotCell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          if (value != null)
            Text(value!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ]),
        if (dots != null && dots!.isNotEmpty) ...[
          const SizedBox(height: 6),
          StreakDots(days: dots!, color: color, cell: dotCell),
        ],
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note!, style: TextStyle(fontSize: 10.5, color: T.subText(context))),
        ],
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// 统计小方块：图标底板用 sm 圆角，比外层卡片小一档（参考实现的嵌套规则）
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tint = T.primary,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: PanelCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: dark ? 0.18 : 0.12),
                borderRadius: T.sm,
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: T.subText(context))),
                  const SizedBox(height: 2),
                  // 数值可能很大（余额是各账号积分之和），用 scaleDown 整体缩到装得下，
                  // 而不是截成省略号。
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = T.primary, this.bg});
  final String text;
  final Color color;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? color.withValues(alpha: dark ? 0.2 : 0.1),
        borderRadius: T.pill,
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: T.red500),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12, color: T.red500))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重试', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class LoadingBox extends StatelessWidget {
  const LoadingBox({super.key, this.height = 120});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}
