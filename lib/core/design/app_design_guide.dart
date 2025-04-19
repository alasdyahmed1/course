import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Design guide based on login_screen.dart to maintain consistent UI across the app
class AppDesignGuide {
  /// Container styling with translucent white background
  /// as used in forms and content areas
  static BoxDecoration getContainerDecoration({
    double opacity = 0.65,
    double borderRadius = 13,
    Color borderColor = AppColors.buttonPrimary,
    double borderWidth = 1.5,
  }) {
    return BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor.withOpacity(0.1),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Input decoration as used in login form fields
  static InputDecoration getInputDecoration({
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

  /// Primary button style as used in login button
  static ButtonStyle getPrimaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.buttonPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 12,
      ),
    );
  }

  /// Secondary button style
  static ButtonStyle getSecondaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.buttonSecondary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 12,
      ),
    );
  }

  /// Third button style
  static ButtonStyle getThirdButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.buttonThird,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 12,
      ),
    );
  }

  /// Builds a container with icon as used in various parts of the app
  static Widget buildIconContainer({
    required IconData icon,
    required Color color,
    double size = 20,
    double containerSize = 40,
    double borderRadius = 8,
  }) {
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        size: size,
        color: color,
      ),
    );
  }

  /// Section title style following app design language
  static Widget buildSectionTitle(String title,
      {double fontSize = 14, FontWeight fontWeight = FontWeight.bold}) {
    return Text(
      title,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// Info card with icon and content
  static Widget buildInfoCard({
    required Widget content,
    required IconData icon,
    Color iconColor = AppColors.buttonPrimary,
    Color backgroundColor = Colors.white,
    double opacity = 0.65,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(opacity),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: content),
        ],
      ),
    );
  }

  /// Gradient background as used in main screens
  static BoxDecoration getGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primaryLight,
          AppColors.primaryMedium,
          AppColors.primaryBg,
        ],
      ),
    );
  }

  /// Build a standard form field following login screen pattern
  static Widget buildFormField({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          alignment: Alignment.centerRight,
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
            decoration: getInputDecoration(
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
    );
  }

  /// Action button as used in various parts of the app
  static Widget buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color color = AppColors.buttonPrimary,
    double fontSize = 12,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: fontSize + 2,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
