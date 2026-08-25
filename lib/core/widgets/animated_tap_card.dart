import 'package:flutter/material.dart';
import 'package:tripproject/core/constants/app_constants.dart';

class AnimatedTapCard extends StatefulWidget {
  const AnimatedTapCard({
    super.key,
    required this.child,
    this.onTap,
    this.heroTag,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? heroTag;

  @override
  State<AnimatedTapCard> createState() => _AnimatedTapCardState();
}

class _AnimatedTapCardState extends State<AnimatedTapCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.cardAnimationDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    Widget card = GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );

    if (widget.heroTag != null) {
      card = Hero(tag: widget.heroTag!, child: card);
    }

    return card;
  }
}
