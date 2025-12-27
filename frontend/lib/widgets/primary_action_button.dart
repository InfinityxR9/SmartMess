import 'package:flutter/material.dart';
import 'package:smart_mess/theme/app_tokens.dart';

class PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const PrimaryActionButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        );
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.md),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: isLoading ? null : onPressed,
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppGradients.accent,
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: AppShadows.glow,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: AppSizes.iconSm, color: AppColors.primary),
                          const SizedBox(width: 8),
                        ],
                        Text(label, style: textStyle),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
