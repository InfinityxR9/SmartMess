import 'package:flutter/material.dart';
import 'package:smart_mess/theme/app_tokens.dart';

class SkeletonBox extends StatefulWidget {
  final double height;
  final double width;
  final BorderRadius borderRadius;

  const SkeletonBox({
    Key? key,
    required this.height,
    required this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.md)),
  }) : super(key: key);

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: AppColors.outlineSubtle,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final int lineCount;

  const SkeletonCard({Key? key, this.lineCount = 3}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const SkeletonBox(
                  height: 44,
                  width: 44,
                  borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(height: 12, width: 160),
                      SizedBox(height: 10),
                      SkeletonBox(height: 10, width: 200),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...List.generate(
              lineCount,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SkeletonBox(
                    height: 10,
                    width: index.isEven ? 220 : 180,
                    borderRadius:
                        const BorderRadius.all(Radius.circular(AppRadii.sm)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final int lineCount;

  const SkeletonList({
    Key? key,
    this.itemCount = 3,
    this.lineCount = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SkeletonCard(lineCount: lineCount),
        ),
      ),
    );
  }
}
