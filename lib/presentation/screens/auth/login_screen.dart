import 'package:flutter/material.dart';
import 'package:mycourses/presentation/screens/home/guest_home_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'dart:math' as math;
import 'register_screen.dart';
import '../../../core/services/supabase_service.dart';
import '../../screens/home_screen.dart';
import '../../screens/admin/admin_dashboard.dart';
import 'verification_code_screen.dart';
import '../../../core/utils/app_transitions.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  late AnimationController _ringController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  InputDecoration _getInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.hintColor.withOpacity(0.5),
        fontSize: 13,
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(
          icon,
          color: AppColors.buttonPrimary,
          size: 20,
        ),
      ),
      suffixIcon: suffixIcon,
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
    );
  }

  // Add email validation function
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال البريد الإلكتروني';
    }

    // Email pattern for validation
    final emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (!emailPattern.hasMatch(value)) {
      return 'الرجاء إدخال بريد إلكتروني صحيح';
    }

    return null;
  }

  // Add password validation function
  String? _validatePassword(String? value) {
    if (value?.isEmpty ?? true) {
      return 'الرجاء إدخال كلمة المرور';
    }
    if (value!.length < 8) {
      return 'كلمة المرور يجب 8 أحرف على الأقل';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'يجب ان يحتوي حرف كبير واحد على الأقل';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'يجب ان يحتوي رقم واحد على الأقل';
    }
    return null;
  }

  // تعديل أنيميشن تسجيل الدخول
  Widget _buildAnimatedIcon() {
    return Builder(
      builder: (context) {
        if (context.findAncestorWidgetOfExactType<Hero>() != null) {
          // إذا كان داخل Hero widget, نعرض الأيقونة بدون أنيميشن
          return Container(
            width: 60,
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.accent.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person,
              size: 24,
              color: AppColors.accent,
            ),
          );
        }

        // إذا لم يكن داخل Hero, نعرض الأنيميشن
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Container(
              width: 60,
              height: 45,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Transform.translate(
                    offset: Offset(40 * (1 - value), 0),
                    child: Opacity(
                      opacity: value,
                      child: const Icon(
                        Icons.person,
                        size: 24,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        final response = await SupabaseService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (mounted) {
          switch (response['status']) {
            case 'verification_needed':
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(response['message']),
                  backgroundColor: AppColors.warning,
                  duration: const Duration(seconds: 3),
                ),
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => VerificationCodeScreen(
                    email: _emailController.text,
                  ),
                ),
              );
              break;

            case 'rate_limit':
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(response['message']),
                  backgroundColor: AppColors.warning,
                  duration: Duration(seconds: response['waitTime'] ?? 3),
                ),
              );
              break;

            case 'success':
              // عرض رسالة النجاح فقط
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تسجيل الدخول بنجاح'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 2),
                ),
              );

              // إضافة تأخير قصير قبل الانتقال
              await Future.delayed(const Duration(milliseconds: 500));

              if (response['is_admin'] == true) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboard()),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }
              break;

            default:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(response['message'] ?? 'حدث خطأ غير متوقع'),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 4),
                ),
              );
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
        }
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
              // زر تصفح الكورسات
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                child: InkWell(
                  onTap: () {
                    // Navigate to home screen
                      Navigator.push(
                      context,
                      AppTransitions.smart(
                        page: const GuestHomeScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Hero(
                          tag: HeroTags.browseText,
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'تصفح الكورسات بدون حساب',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: AppColors.buttonThird,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward,
                                  color: AppColors.buttonThird,
                                  size: 17,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // محتوى الصفحة
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // نفس تصميم الأيقونة المتحركة
                      Center(
                        child: Hero(
                          tag: HeroTags.authAnimation,
                          child: Material(
                            color: Colors.transparent,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              AppColors.accent.withOpacity(0.2),
                                          blurRadius: 20,
                                          spreadRadius:
                                              5 * _pulseAnimation.value,
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Animated rings
                                        ...List.generate(3, (index) {
                                          return AnimatedBuilder(
                                            animation: _ringController,
                                            builder: (context, _) {
                                              return Transform.rotate(
                                                angle: _ringController.value *
                                                    math.pi *
                                                    2 *
                                                    (index.isEven ? 1 : -1),
                                                child: Container(
                                                  width: 105 - (index * 15),
                                                  height: 105 - (index * 15),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: AppColors.accent
                                                          .withOpacity(0.1),
                                                      width: 2,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            45),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        }),
                                        // إزالة TweenAnimationBuilder واستخدام الأيقونة مباشرة
                                        _buildAnimatedIcon(),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // عنوان الصفحة
                      Hero(
                        tag: HeroTags.pageTitle,
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
                          child: Text(
                            'تسجيل الدخول',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              // fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // نموذج تسجيل الدخول
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildFormField(
                                title: 'البريد الالكتروني',
                                controller: _emailController,
                                hint: 'أدخل بريدك الإلكتروني',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 12),
                              _buildFormField(
                                title: 'كلمة المرور',
                                controller: _passwordController,
                                hint: 'أدخل كلمة المرور',
                                icon: Icons.lock_outlined,
                                isPassword: true,
                                isPasswordVisible: _isPasswordVisible,
                                onTogglePassword: () => setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                }),
                                validator: _validatePassword,
                              ),
                              const SizedBox(
                                  height: 12), // إعادة المسافة الأصلية
                              // زر تسجيل الدخول
                              Hero(
                                tag: HeroTags.actionButton,
                                child: Container(
                                  width: double.infinity,
                                  height: 42,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
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
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'تسجيل الدخول',
                                            style: AppTextStyles.titleLarge
                                                .copyWith(
                                              color: Colors.white,
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      AppTransitions.forgotPassword(
                                        page: const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'نسيت كلمة المرور؟',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.buttonPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'ليس لديك حساب؟',
                                    style: TextStyle(
                                      color: AppColors.hintColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        AppTransitions.authTransition(
                                          page: const RegisterScreen(),
                                          isReverse: true,
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'سجل الآن',
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        color: AppColors.buttonPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _buildFormField({
    required String title,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    String? Function(String?)? validator,
  }) {
    final heroTag = isPassword ? HeroTags.passwordField : HeroTags.emailField;

    return Hero(
      tag: heroTag,
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
              alignment: Alignment.centerRight, // محاذاة العنوان لليمين
              padding: const EdgeInsets.only(bottom: 8, right: 4),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Directionality(
              textDirection: TextDirection.rtl,
              child: TextFormField(
                controller: controller,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                keyboardType: keyboardType,
                obscureText: isPassword && !isPasswordVisible,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: _getInputDecoration(
                  label: '',
                  hint: hint,
                  icon: icon,
                  suffixIcon: isPassword
                      ? IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.buttonPrimary,
                            size: 18,
                          ),
                          onPressed: onTogglePassword,
                        )
                      : null,
                ),
                validator: validator,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
