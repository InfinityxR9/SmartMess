import 'package:flutter/material.dart';
import 'package:smart_mess/theme/app_tokens.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.icon,
    this.padding = const EdgeInsets.only(top: 12, bottom: 8),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.inkMuted,
        );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(
                    icon,
                    size: AppSizes.iconSm,
                    color: AppColors.accent,
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  style: titleStyle,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: subtitleStyle,
            ),
          ],
          const SizedBox(height: 10),
          Container(
            height: 3,
            width: 48,
            decoration: BoxDecoration(
              gradient: AppGradients.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}
