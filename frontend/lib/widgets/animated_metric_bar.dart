import 'package:flutter/material.dart';
import 'package:smart_mess/theme/app_tokens.dart';

class AnimatedMetricBar extends StatelessWidget {
  final double percentage;
  final Color color;
  final double height;
  final bool showGlow;

  const AnimatedMetricBar({
    Key? key,
    required this.percentage,
    required this.color,
    this.height = 8,
    this.showGlow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final clamped = percentage.clamp(0, 100) / 100;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: clamped),
          duration: AppMotion.slow,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Stack(
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: AppColors.outlineSubtle,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
                Container(
                  height: height,
                  width: width * value,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(height),
                    boxShadow: showGlow ? AppShadows.glow : null,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
