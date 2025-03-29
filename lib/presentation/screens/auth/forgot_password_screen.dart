import 'package:flutter/material.dart';
import 'package:mycourses/core/utils/app_transitions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/supabase_service.dart';
import 'password_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        // إرسال رمز التحقق بدلاً من الرابط
        await SupabaseService.sendPasswordResetOTP(_emailController.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال رمز التحقق إلى بريدك الإلكتروني'),
              backgroundColor: AppColors.success,
            ),
          );

          // الانتقال إلى شاشة التحقق
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PasswordVerificationScreen(
                email: _emailController.text,
              ),
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
        if (mounted) setState(() => _isLoading = false);
      }
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
              // نفس padding للرأس كما في صفحة تسجيل الدخول
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.buttonPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  // تصحيح الـ padding ليتطابق مع الصفحات الأخرى
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        const Icon(
                          Icons.lock_reset,
                          size: 80,
                          color: AppColors.buttonPrimary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'نسيت كلمة المرور؟',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // تصحيح هيكل حاوية الفورم
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // توحيد تنسيق حقل البريد الإلكتروني
                              Container(
                                // إزالة padding الإضافي للمطابقة مع صفحة تسجيل الدخول
                                child: Hero(
                                  tag: HeroTags.emailField,
                                  flightShuttleBuilder: (
                                    BuildContext flightContext,
                                    Animation<double> animation,
                                    HeroFlightDirection flightDirection,
                                    BuildContext fromHeroContext,
                                    BuildContext toHeroContext,
                                  ) {
                                    return Material(
                                      color: Colors.transparent,
                                      child: toHeroContext.widget,
                                    );
                                  },
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(bottom: 8, right: 4),
                                          child: const Text(
                                            'البريد الالكتروني',
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Directionality(
                                          textDirection: TextDirection.rtl,
                                          child: TextFormField(
                                            controller: _emailController,
                                            textAlign: TextAlign.right,
                                            textDirection: TextDirection.rtl,
                                            keyboardType: TextInputType.emailAddress,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 13,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'أدخل بريدك الإلكتروني',
                                              hintStyle: TextStyle(
                                                color: AppColors.hintColor.withOpacity(0.5),
                                                fontSize: 13,
                                              ),
                                              prefixIcon: Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                                child: const Icon(
                                                  Icons.email_outlined,
                                                  color: AppColors.buttonPrimary,
                                                  size: 20,
                                                ),
                                              ),
                                              filled: true,
                                              fillColor: Colors.white.withOpacity(0.65),
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(13),
                                                borderSide: BorderSide(
                                                  color: AppColors.buttonPrimary.withOpacity(0.1),
                                                  width: 1.5,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(13),
                                                borderSide: BorderSide(
                                                  color: AppColors.buttonPrimary.withOpacity(0.1),
                                                  width: 1.5,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(13),
                                                borderSide: const BorderSide(
                                                  color: AppColors.buttonPrimary,
                                                  width: 1.5,
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(13),
                                                borderSide: const BorderSide(
                                                  color: AppColors.error,
                                                  width: 1.5,
                                                ),
                                              ),
                                              focusedErrorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(13),
                                                borderSide: const BorderSide(
                                                  color: AppColors.error,
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value?.isEmpty ?? true) {
                                                return 'الرجاء إدخال البريد الإلكتروني';
                                              }
                                              final emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                              if (!emailPattern.hasMatch(value!)) {
                                                return 'الرجاء إدخال بريد إلكتروني صحيح';
                                              }
                                              return null;
                                            },
                                            autovalidateMode: AutovalidateMode.onUserInteraction,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Hero(
                                tag: HeroTags.actionButton,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: double.infinity,
                                    height: 42,
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _resetPassword,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.buttonPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(13),
                                        ),
                                        elevation: 0,
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
                                              'إرسال رمز التحقق',
                                              style: AppTextStyles.titleLarge.copyWith(
                                                color: Colors.white,
                                                fontSize: 15,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    _emailController.dispose();
    super.dispose();
  }
}
