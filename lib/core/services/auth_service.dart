import '../config/env_config.dart';
import 'supabase_service.dart';

class AuthService {
  // استخدام المثيل من SupabaseService
  static final _supabase = SupabaseService.supabase;

  static bool isAdmin(String? email) {
    return email?.toLowerCase() == EnvConfig.adminEmail.toLowerCase();
  }

  static Future<bool> hasAdminAccess() async {
    final user = _supabase.auth.currentUser;
    return isAdmin(user?.email);
  }
}
