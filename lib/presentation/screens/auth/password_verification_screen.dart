import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/supabase_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'reset_password_screen.dart';
import 'forgot_password_screen.dart';

class PasswordVerificationScreen extends StatefulWidget {
  final String email;

  const PasswordVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<PasswordVerificationScreen> createState() => _PasswordVerificationScreenState();
}

class _PasswordVerificationScreenState extends State<PasswordVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  Timer? _timer;
  int _resendDelay = 60;

  // للأنيميشن
  late AnimationController _iconController;
  late Animation<double> _iconAnimation;
  late PinTheme _pinTheme;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _startResendTimer();
    _initializePinTheme();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('تم إرسال رمز التحقق إلى بريدك الإلكتروني'),
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 5),
          ),
        );
      }
    });
  }

  void _initializeAnimation() {
    _iconController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _iconAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeInOutBack,
    ));

    _iconController.repeat(reverse: true);
  }

  void _initializePinTheme() {
    _pinTheme = PinTheme(
      shape: PinCodeFieldShape.box,
      borderRadius: BorderRadius.circular(12),
      fieldHeight: 45,
      fieldWidth: 45,
      activeFillColor: Colors.white,
      inactiveFillColor: Colors.white,
      selectedFillColor: Colors.white,
      activeColor: AppColors.buttonPrimary,
      inactiveColor: AppColors.buttonPrimary.withOpacity(0.3),
      selectedColor: AppColors.buttonPrimary,
    );
  }

  void _startResendTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendDelay > 0) {
        setState(() => _resendDelay--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) return;

    setState(() => _isLoading = true);
    try {
      final isValid = await SupabaseService.verifyPasswordResetOTP(
        email: widget.email,
        token: _codeController.text,
      );

      if (mounted) {
        if (isValid) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(
                email: widget.email,
                token: _codeController.text,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رمز التحقق غير صحيح'),
              backgroundColor: AppColors.error,
            ),
          );
          _codeController.clear();
          // تحديث لون الحقل للأحمر
          setState(() {
            _pinTheme = PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(12),
              fieldHeight: 45,
              fieldWidth: 45,
              activeFillColor: Colors.white,
              inactiveFillColor: Colors.white,
              selectedFillColor: Colors.white,
              activeColor: AppColors.error,
              inactiveColor: AppColors.error.withOpacity(0.3),
              selectedColor: AppColors.error,
            );
          });
          
          // إعادة لون الحقل للون الأساسي بعد 3 ثواني
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _initializePinTheme();
              });
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_isResending || _resendDelay > 0) return;

    setState(() => _isResending = true);
    try {
      await SupabaseService.sendPasswordResetOTP(widget.email);
      
      setState(() => _resendDelay = 60);
      _startResendTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رمز جديد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
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
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.buttonPrimary,
                  ),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  ),
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // أيقونة متحركة
                      AnimatedBuilder(
                        animation: _iconAnimation,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _iconAnimation.value,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock_reset,
                                size: 50,
                                color: AppColors.buttonPrimary,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Container(
                        alignment: Alignment.center,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            'التحقق من هويتك',
                            style: AppTextStyles.titleLarge.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          'تم إرسال رمز التحقق إلى',
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          widget.email,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.buttonPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: PinCodeTextField(
                          appContext: context,
                          length: 6,
                          controller: _codeController,
                          onChanged: (_) {},
                          onCompleted: (_) => _verifyCode(),
                          pinTheme: _pinTheme,
                          animationType: AnimationType.scale,
                          keyboardType: TextInputType.number,
                          enableActiveFill: true,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'تحقق من الرمز',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextButton(
                        onPressed: _resendDelay > 0 ? null : _resendCode,
                        child: Text(
                          _resendDelay > 0
                              ? 'إعادة الإرسال خلال $_resendDelay ثانية'
                              : 'إعادة إرسال الرمز',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: _resendDelay > 0
                                ? AppColors.hintColor
                                : AppColors.buttonPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }
}
