import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AnimatedGradientBox extends StatefulWidget {
  final Widget child;
  const AnimatedGradientBox({super.key, required this.child});

  @override
  State<AnimatedGradientBox> createState() => _AnimatedGradientBoxState();
}

class _AnimatedGradientBoxState extends State<AnimatedGradientBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _topAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        weight: 1.0,
        tween: Tween<Alignment>(
          begin: const Alignment(-1.0, -1.0),
          end: const Alignment(1.0, -1.0),
        ),
      ),
    ]).animate(_controller);

    _bottomAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        weight: 1.0,
        tween: Tween<Alignment>(
          begin: const Alignment(1.0, 1.0),
          end: const Alignment(-1.0, 1.0),
        ),
      ),
    ]).animate(_controller);
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
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _topAlignmentAnimation.value,
              end: _bottomAlignmentAnimation.value,
              colors: const [
                AppColors.primaryLight,
                AppColors.primaryMedium,
                AppColors.primaryBg,
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
