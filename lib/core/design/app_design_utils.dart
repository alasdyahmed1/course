import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Utility class that follows the login screen UI patterns
class AppDesignUtils {
  /// Returns the standard InputDecoration used in the login screen
  static InputDecoration getStandardInputDecoration({
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

  /// Standard button style used in the app
  static ButtonStyle getStandardButtonStyle({
    Color backgroundColor = AppColors.buttonPrimary,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
      elevation: 0,
    );
  }

  /// Standard form field title style
  static TextStyle getFormFieldTitleStyle() {
    return const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
  }

  /// Standard gradient background
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

  /// Standard container styling for video player
  static BoxDecoration getVideoPlayerDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(13),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ],
    );
  }

  /// Returns a fixed size container for video player to prevent layout shifts
  static Widget getStableVideoContainer(
      {required Widget child, required double width}) {
    final aspectRatio = 16 / 9;
    final height = width / aspectRatio;

    return Container(
      width: width,
      height: height,
      decoration: getVideoPlayerDecoration(),
      child: child,
    );
  }
}
