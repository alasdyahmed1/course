import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/supabase_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'login_screen.dart';
import 'register_screen.dart';

class VerificationCodeScreen extends StatefulWidget {
  final String email;

  const VerificationCodeScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  Timer? _timer;
  int _resendDelay = 60;

  // للأنيميشن
  late AnimationController _iconController;
  late Animation<double> _iconAnimation;

  // أضف متغير لحفظ نمط حقل PIN في بداية الكلاس
  late PinTheme _pinTheme;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _startResendTimer();

    // تهيئة نمط حقل PIN
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

    // زيادة مدة عرض الرسالة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('تم إرسال رمز التحقق إلى بريدك الإلكتروني'),
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 5), // زيادة المدة
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
      final response = await SupabaseService.verifyOTP(
        email: widget.email,
        token: _codeController.text,
      );

      if (mounted) {
        switch (response['status']) {
          case 'success':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم التحقق بنجاح!'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
            
            await Future.delayed(const Duration(seconds: 1));
            
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
            break;

          case 'expired':
          case 'invalid':
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message']),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 3),
              ),
            );
            // تصفير حقل الإدخال وتغيير لونه للأحمر
            _codeController.clear();
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
            break;

          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message']),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 3),
              ),
            );
            break;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // إعادة لون الحقل للون الأساسي بعد ثانيتين
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
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
            });
          }
        });
      }
    }
  }

  // تحديث دالة _resendCode لتتوافق مع التغييرات
  Future<void> _resendCode() async {
    if (_isResending || _resendDelay > 0) return;

    setState(() => _isResending = true);
    try {
      final message = await SupabaseService.resendOTP(
        email: widget.email,
      );
      
      setState(() => _resendDelay = 60);
      _startResendTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
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
              // تغيير محاذاة زر الرجوع إلى اليمين مع تقليل المسافة
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  padding: EdgeInsets.zero, // إزالة padding الداخلي
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.buttonPrimary,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                ),
              ),
              
              // تقليل المسافة بين زر الرجوع والمحتوى
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // إزالة المسافة الزائدة
                      const SizedBox(height: 30), // حذف هذا السطر

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
                                Icons.security,
                                size: 50,
                                color: AppColors.buttonPrimary,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // ...existing code...
                      const SizedBox(height: 20),
                        
                        // تعديل اتجاه النص وتوسيطه
                        Container(
                          alignment: Alignment.center,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              'التحقق من البريد الإلكتروني',
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
                        // حقل إدخال الرمز
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: PinCodeTextField(
                            appContext: context,
                            length: 6,
                            controller: _codeController,
                            onChanged: (_) {},
                            onCompleted: (_) => _verifyCode(),
                            pinTheme: _pinTheme, // استخدام المتغير المحدث
                            animationType: AnimationType.scale,
                            keyboardType: TextInputType.number,
                            enableActiveFill: true,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // زر التحقق
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
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
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
                        // زر إعادة الإرسال
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
    
    // مهم: التأكد من عدم استخدام Controller بعد إلغائه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _codeController.dispose();
      }
    });
    
    super.dispose();
  }
}
