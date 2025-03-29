import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_size/window_size.dart';

import 'core/config/env_config.dart';
import 'core/services/platform_helper.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/webview_platform_implementation.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  // Call WidgetsFlutterBinding.ensureInitialized first to initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize WebView platform - تهيئة WebView بشكل صحيح في بداية التطبيق
  try {
    WebViewPlatformImplementation.initializeWebView();
    debugPrint('✅ WebView platform initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Error initializing WebView platform: $e');
  }

  // Initialize MediaKit with error handling
  try {
    MediaKit.ensureInitialized();
    debugPrint('✅ MediaKit initialized successfully');
  } catch (e) {
    debugPrint('⚠️ MediaKit initialization failed: $e');
    // Continue with the app even if MediaKit fails - we'll handle fallbacks in the player
  }

  if (PlatformHelper.isWindows) {
    setWindowTitle('كورساتي');
    setWindowMinSize(const Size(400, 300));
    setWindowMaxSize(Size.infinite);
  }

  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
    debug: true,
  );

  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  final navigatorKey = GlobalKey<NavigatorState>();
  MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'كورساتي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''),
      ],
      locale: const Locale('ar', ''),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
