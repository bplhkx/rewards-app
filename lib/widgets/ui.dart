import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// 扁平卡片：参考实现里 96% 的"卡片"不走 Material Card，就是圆角容器 + 描边。
class PanelCard extends StatelessWidget {
  const PanelCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: T.surface(context),
      borderRadius: T.lg,
      child: InkWell(
        borderRadius: T.lg,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: T.lg,
            border: Border.all(color: T.hairline(context)),
          ),
          padding: padding ?? const EdgeInsets.all(T.gap),
          child: child,
        ),
      ),
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
