import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AnimatedScreenIcon extends StatelessWidget {
  final double value;
  final bool isLogin;

  const AnimatedScreenIcon({
    super.key,
    required this.value,
    this.isLogin = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // شاشة اللابتوب
        Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent.withOpacity(0.2),
                AppColors.accent.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.accent.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: CustomPaint(
            painter: ScreenGlowPainter(
              progress: value,
              color: AppColors.accent,
            ),
          ),
        ),

        // قاعدة اللابتوب مع ظل
        Positioned(
          bottom: -12,
          left: 10,
          right: 10,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),

        // تأثير الضوء المتحرك
        Positioned(
          top: 5,
          left: 5,
          right: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(1.5 - value * 2.5, 0),
                  end: const Alignment(-0.5, 0),
                  colors: [
                    Colors.white.withOpacity(0.5),
                    Colors.white.withOpacity(0),
                    Colors.white.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        ),

        // أيقونة المستخدم
        if (isLogin)
          // حركة الدخول من اليمين
          Positioned(
            right: -30 + (110 * value),
            top: 15,
            child: Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Icon(
                Icons.person,
                size: 30,
                color: AppColors.accent.withOpacity(value),
              ),
            ),
          )
        else
          // حركة التسجيل من الأعلى
          Positioned(
            right: 25,
            top: -20 + (35 * value),
            child: Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Icon(
                Icons.person_add,
                size: 30,
                color: AppColors.accent.withOpacity(value),
              ),
            ),
          ),

        // تأثير الومضات
        ...List.generate(3, (index) {
          final delay = index * 0.2;
          final progress = (value - delay).clamp(0.0, 1.0);
          return Positioned(
            right: 20 + (index * 10.0),
            top: 15,
            child: Opacity(
              opacity: (1 - progress) * 0.5,
              child: Transform.scale(
                scale: 0.5 + (progress * 0.5),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class ScreenGlowPainter extends CustomPainter {
  final double progress;
  final Color color;

  ScreenGlowPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withOpacity(0.5 * progress),
          color.withOpacity(0.2 * progress),
        ],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * (0.2 + (0.1 * progress)),
        size.width,
        size.height * 0.2,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
