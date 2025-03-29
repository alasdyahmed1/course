import 'package:flutter/material.dart';
import 'package:mycourses/core/services/supabase_service.dart';

class AuthUtils {
  /// Shows a confirmation dialog before logging out
  static Future<bool> showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    // Handle logout if confirmed
    if (result == true) {
      await SupabaseService.supabase.auth.signOut();
      return true;
    }

    return false;
  }

  /// Logout button that can be used in any screen
  static Widget logoutButton({
    required BuildContext context,
    required void Function() onLogout,
    Color? color,
    double? iconSize,
  }) {
    return IconButton(
      icon: Icon(
        Icons.logout_rounded,
        color: color ?? Colors.white,
        size: iconSize ?? 24,
      ),
      onPressed: () async {
        final confirmed = await showLogoutConfirmation(context);
        if (confirmed && context.mounted) {
          onLogout();
        }
      },
      tooltip: 'تسجيل الخروج',
    );
  }
}
