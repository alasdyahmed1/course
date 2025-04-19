import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/providers/player_options_provider.dart';

class CourseVideoHeader extends StatefulWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final String? selectedPlayerId;
  final Function(String) onPlayerChanged;
  final bool isDrmProtected;
  final int? orderNumber;

  const CourseVideoHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.onRefresh,
    required this.selectedPlayerId,
    required this.onPlayerChanged,
    required this.isDrmProtected,
    this.orderNumber,
  });

  @override
  State<CourseVideoHeader> createState() => _CourseVideoHeaderState();
}

class _CourseVideoHeaderState extends State<CourseVideoHeader> {
  // إضافة متغير للتحكم في حالة فتح القائمة
  bool _isPlayerMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    // الحصول على خيار المشغل المحدد حالياً
    final selectedPlayerOption = PlayerOptionsProvider.getPlayerOptionById(
        widget.selectedPlayerId ?? 'iframe');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // عنوان الكورس - تعديل لعرض أفضل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.orderNumber != null)
                  Text(
                    'الفيديو #${widget.orderNumber}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),

          // مساحة إضافية لمنع التداخل
          const SizedBox(width: 4),

          // أزرار إضافية
          IconButton(
            onPressed: widget.onRefresh,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          // استخدام PopupMenuButton لقائمة المشغلات
          PopupMenuButton<String>(
            // تغيير أيقونة القائمة عند فتحها
            icon: _isPlayerMenuOpen
                ? const Icon(Icons.close)
                : Stack(
                    children: [
                      const Icon(Icons.video_settings),
                      if (widget.isDrmProtected)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
            tooltip: 'نوع المشغل',
            offset: const Offset(0, 40),
            onOpened: () {
              setState(() {
                _isPlayerMenuOpen = true;
              });
            },
            onCanceled: () {
              setState(() {
                _isPlayerMenuOpen = false;
              });
            },
            onSelected: (String value) {
              widget.onPlayerChanged(value);
              setState(() {
                _isPlayerMenuOpen = false;
              });
            },
            itemBuilder: (BuildContext context) {
              // عرض خيارات المشغلات المتوفرة
              return PlayerOptionsProvider.getAvailablePlayerOptions()
                  .where((option) =>
                      !widget.isDrmProtected ||
                      option.supportsDrm ||
                      option.id == 'diagnose')
                  .map((option) {
                return PopupMenuItem<String>(
                  value: option.id,
                  child: Row(
                    children: [
                      // إضافة علامة للعنصر المحدد حالياً
                      if (option.id == selectedPlayerOption.id)
                        const Icon(Icons.check,
                            color: AppColors.buttonPrimary, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      // أيقونة المشغل
                      Icon(
                        option.icon,
                        color: option.id == selectedPlayerOption.id
                            ? AppColors.buttonPrimary
                            : Colors.grey.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      // اسم المشغل
                      Text(
                        option.name,
                        style: TextStyle(
                          color: option.id == selectedPlayerOption.id
                              ? AppColors.buttonPrimary
                              : Colors.grey.shade900,
                          fontWeight: option.id == selectedPlayerOption.id
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      // إضافة شارة DRM إذا كان المشغل يدعمه
                      if (option.supportsDrm) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DRM',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
    );
  }
}
