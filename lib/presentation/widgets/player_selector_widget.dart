import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/models/player_option.dart';
import 'package:mycourses/core/providers/player_options_provider.dart';

class PlayerSelectorWidget extends StatelessWidget {
  /// المشغل المحدد حالياً
  final String selectedPlayerId;

  /// استدعاء عند تغيير المشغل
  final Function(String) onPlayerChanged;

  /// ما إذا كان الفيديو الحالي محمي بتقنية DRM
  final bool isDrmProtected;

  const PlayerSelectorWidget({
    super.key,
    required this.selectedPlayerId,
    required this.onPlayerChanged,
    this.isDrmProtected = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'اختيار مشغل الفيديو',
      offset: const Offset(0, 40),
      onSelected: onPlayerChanged,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      // إزالة استخدام Tooltip هنا لتجنب الأخطاء المتكررة
      itemBuilder: (context) {
        return PlayerOptionsProvider.getAvailablePlayerOptions()
            .where((option) => !isDrmProtected || option.supportsDrm)
            .map((PlayerOption option) {
          return PopupMenuItem<String>(
            value: option.id,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                option.icon,
                color: option.color ?? AppColors.buttonPrimary,
              ),
              title: Row(
                children: [
                  Text(
                    option.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (option.requiresExternalDependencies)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
              subtitle: option.description != null
                  ? Text(
                      option.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    )
                  : null,
              trailing: option.id == selectedPlayerId
                  ? Icon(
                      Icons.check_circle,
                      color: option.color ?? AppColors.buttonPrimary,
                    )
                  : null,
            ),
          );
        }).toList();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getSelectedOption().icon,
            size: 18,
            color: _getSelectedOption().color ?? AppColors.buttonPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            _getSelectedOption().name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _getSelectedOption().color ?? AppColors.buttonPrimary,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.arrow_drop_down,
            size: 16,
          ),
        ],
      ),
    );
  }

  PlayerOption _getSelectedOption() {
    return PlayerOptionsProvider.getPlayerOptionById(selectedPlayerId);
  }
}
