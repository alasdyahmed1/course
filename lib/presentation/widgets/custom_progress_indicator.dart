import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_colors.dart';

class CustomProgressIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const CustomProgressIndicator({
    super.key,
    this.size = 40.0,
    this.strokeWidth = 4.0,
    this.color = AppColors.buttonPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(color),
        strokeWidth: strokeWidth,
      ),
    );
  }
}
