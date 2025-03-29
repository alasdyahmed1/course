import 'package:shared_preferences/shared_preferences.dart';

/// خدمة تخزين تفضيلات المشغل
class PlayerPreferencesService {
  static const String _playerTypeKey = 'selected_player_type';

  /// حفظ نوع المشغل المفضل
  static Future<void> savePlayerType(String playerType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playerTypeKey, playerType);
  }

  /// جلب نوع المشغل المفضل (أو القيمة الافتراضية إذا لم يتم تعيينه)
  static Future<String> getPlayerType({String defaultValue = 'iframe'}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_playerTypeKey) ?? defaultValue;
  }
}
