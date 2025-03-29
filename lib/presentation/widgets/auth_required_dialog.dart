import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_transitions.dart';
import '../screens/auth/register_screen.dart';

class AuthRequiredDialog extends StatelessWidget {
  const AuthRequiredDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 40), // تحكم أفضل في العرض
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(
          horizontal: 12, // زيادة الهوامش الداخلية
          vertical: 12, // زيادة الهوامش الداخلية
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryLight,
              AppColors.primaryMedium,
              AppColors.primaryBg,
            ],
            stops: const [0.2, 0.6, 0.9],
          ),
          borderRadius: BorderRadius.circular(36), // تقليل قليلاً للتناسق
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1.5, // زيادة سمك الحدود قليلاً
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBg.withOpacity(0.3),
              blurRadius: 24, // زيادة التأثير
              offset: const Offset(0, 8),
              spreadRadius: 2, // إضافة انتشار للظل
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // تحديث حجم وتأثيرات الأيقونة
            Container(
              padding: const EdgeInsets.all(16), // زيادة حجم الدائرة
              margin:
                  const EdgeInsets.only(bottom: 8), // إضافة مسافة أسفل الأيقونة
              decoration: BoxDecoration(
                color: AppColors.buttonPrimary.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.buttonPrimary.withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.account_circle_outlined,
                size: 30, // زيادة حجم الأيقونة
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // تحديث لون النصوص لتتناسب مع الخلفية الداكنة
            Text(
              'مطلوب إنشاء حساب',
              style: AppTextStyles.titleMedium.copyWith(
                // color: Colors.white,
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'يجب إنشاء حساب للوصول إلى محتوى الكورس',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                // color: Colors.white.withOpacity(0.9),
                color: AppColors.textPrimary,

                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            // الأزرار
            Row(
              children: [
                // زر الإلغاء
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      'إلغاء',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // زر إنشاء حساب
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        AppTransitions.authTransition(
                          page: const RegisterScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'إنشاء حساب',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
