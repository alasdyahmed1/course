import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
import 'package:mycourses/core/services/supabase_service.dart';
import 'dart:async';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  Timer? _timer;
  int _resendDelay = 60;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
  }

  void _startVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final isVerified = await SupabaseService.isEmailVerified(widget.email);
      if (isVerified) {
        _timer?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم التحقق من البريد الإلكتروني بنجاح!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true); // Return success
        }
      }
    });
  }

  Future<void> _resendVerification() async {
    if (_isResending) return;

    setState(() => _isResending = true);
    try {
      await SupabaseService.resendVerificationEmail(widget.email);
      
      // Start countdown timer
      setState(() => _resendDelay = 60);
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendDelay == 0) {
          timer.cancel();
        } else {
          setState(() => _resendDelay--);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رابط التحقق مرة أخرى'),
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
      setState(() => _isResending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق من البريد الإلكتروني'),
      ),
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 80,
                  color: AppColors.buttonPrimary,
                ),
                const SizedBox(height: 24),
                Text(
                  'تم إرسال رابط التحقق إلى',
                  style: AppTextStyles.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.email,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.buttonPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'يرجى التحقق من بريدك الإلكتروني والضغط على الرابط للتحقق من حسابك',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: _resendDelay == 0 ? _resendVerification : null,
                  child: Text(
                    _resendDelay > 0
                        ? 'إعادة الإرسال بعد $_resendDelay ثانية'
                        : 'إعادة إرسال رابط التحقق',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: _resendDelay == 0
                          ? AppColors.buttonPrimary
                          : AppColors.hintColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
