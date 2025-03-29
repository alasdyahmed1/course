import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/config/env_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../screens/home/guest_home_screen.dart';
import 'admin/admin_dashboard.dart';
import 'auth/register_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _bgController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // تهيئة المتحكمات
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _bgController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // تهيئة الأنيميشن
    _initializeAnimations();

    // تشغيل الأنيميشن
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _startAnimations();
      }
    });

    // التحقق من حالة تسجيل الدخول بعد 3 ثواني
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _checkAuthState();
      }
    });
  }

  Future<void> _checkAuthState() async {
    try {
      final hasSession = await SupabaseService.hasActiveSession();

      if (!mounted) return;

      if (hasSession) {
        final user = SupabaseService.supabase.auth.currentUser;
        final isAdmin =
            user?.email?.toLowerCase() == EnvConfig.adminEmail.toLowerCase();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                isAdmin ? const AdminDashboard() : const GuestHomeScreen(),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const RegisterScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const GuestHomeScreen(),
          ),
        );
      }
    }
  }

  void _initializeAnimations() {
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 40.0,
      ),
    ]).animate(_mainController);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    ));

    _rotateAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: -0.5, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.0),
        weight: 40.0,
      ),
    ]).animate(_mainController);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(_pulseController);
  }

  void _startAnimations() {
    try {
      // بدء الأنيميشن بالترتيب مع التحقق من mounted
      if (!_mainController.isAnimating) {
        _mainController.forward();
      }
      if (!_bgController.isAnimating) {
        _bgController.repeat();
      }
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } catch (e) {
      debugPrint('Animation error: $e');
    }
  }

  @override
  void dispose() {
    // إيقاف الأنيميشن قبل التخلص من الشاشة
    _mainController.stop();
    _bgController.stop();
    _pulseController.stop();

    _mainController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryLight,
              AppColors.primaryMedium,
              AppColors.primaryBg,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Animated background pattern
            AnimatedBuilder(
              animation: _bgController,
              builder: (context, _) {
                return CustomPaint(
                  painter: HexagonPatternPainter(
                    progress: _bgController.value,
                    baseColor: AppColors.accent,
                  ),
                );
              },
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Enhanced animated logo
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: RotationTransition(
                      turns: _rotateAnimation,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 5 * _pulseAnimation.value,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Dynamic rings
                                  ...List.generate(3, (index) {
                                    return AnimatedBuilder(
                                      animation: _bgController,
                                      builder: (context, _) {
                                        return Transform.rotate(
                                          angle: _bgController.value *
                                              math.pi *
                                              2 *
                                              (index.isEven ? 1 : -1),
                                          child: Container(
                                            width: 110 - (index * 15),
                                            height: 110 - (index * 15),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: AppColors.accent
                                                    .withOpacity(0.1),
                                                width: 2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(45),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }),
                                  // Animated stacked icons
                                  Stack(
                                    children: [
                                      Icon(
                                        Icons.laptop_mac,
                                        size: 60,
                                        color:
                                            AppColors.accent.withOpacity(0.9),
                                      ),
                                      Positioned(
                                        top: 13,
                                        left: 17,
                                        child: Icon(
                                          Icons.school,
                                          size: 25,
                                          color:
                                              AppColors.accent.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // App name with fade effect
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'كورساتي',
                      style: AppTextStyles.displayLarge.copyWith(
                        fontSize: 32,
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Animated subtitle
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(_fadeAnimation),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'طريقك نحو التعلم والتطور',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.accent,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Signature at bottom
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'مبرمج ومقدم الكورسات',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أحمد جعفر',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HexagonPatternPainter extends CustomPainter {
  final double progress;
  final Color baseColor;

  HexagonPatternPainter({
    required this.progress,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const hexSize = 50.0;
    final rows = (size.height / (hexSize * 0.75)).ceil();
    final cols = (size.width / (hexSize * math.sqrt(3) / 2)).ceil();

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final isOffset = row.isEven;
        final x = col * hexSize * math.sqrt(3) / 2 +
            (isOffset ? hexSize * math.sqrt(3) / 4 : 0);
        final y = row * hexSize * 0.75;

        final opacity =
            0.05 + 0.05 * math.sin(progress * 2 * math.pi + (x + y) / 30);
        paint.color = baseColor.withOpacity(opacity);

        final path = Path();
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + progress * math.pi / 6;
          final point = Offset(
            x + math.cos(angle) * hexSize / 2,
            y + math.sin(angle) * hexSize / 2,
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(HexagonPatternPainter oldDelegate) => true;
}
