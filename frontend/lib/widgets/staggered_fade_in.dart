import 'package:flutter/material.dart';
import 'package:smart_mess/theme/app_tokens.dart';

class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration baseDelay;

  const StaggeredFadeIn({
    Key? key,
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 80),
  }) : super(key: key);

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _offset = Tween<double>(begin: 12, end: 0).animate(curve);
    Future.delayed(
      Duration(milliseconds: widget.index * widget.baseDelay.inMilliseconds),
      () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _offset.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
