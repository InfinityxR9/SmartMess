import 'package:flutter/material.dart';
import 'package:smart_mess/theme/app_tokens.dart';

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkMuted,
        );

    return Card(
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.outlineSubtle),
          gradient: const LinearGradient(
            colors: [Color(0xFFFDFBF7), Color(0xFFF2F7F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(
                icon,
                size: AppSizes.iconLg,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(title, style: titleStyle),
            const SizedBox(height: 8),
            Text(message, style: bodyStyle),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
