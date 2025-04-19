import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A utility class to manage WebView instances and their lifecycle
/// to prevent memory leaks and improve performance
class WebViewCacheManager {
  // Singleton instance
  static final WebViewCacheManager _instance = WebViewCacheManager._internal();
  factory WebViewCacheManager() => _instance;
  WebViewCacheManager._internal();

  // Cache of WebView controllers with timestamps
  final Map<String, _CachedController> _controllerCache = {};

  // Maximum number of controllers to keep in cache
  final int _maxCachedControllers = 2;

  /// Get or create a WebViewController for the given key and URL
  WebViewController getController(String key, String url) {
    // Clear expired controllers
    _cleanupCache();

    // Return cached controller if available
    if (_controllerCache.containsKey(key)) {
      _controllerCache[key]!.lastUsed = DateTime.now();
      return _controllerCache[key]!.controller;
    }

    // Create new controller
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    // Cache the new controller
    _controllerCache[key] = _CachedController(
      controller: controller,
      lastUsed: DateTime.now(),
    );

    return controller;
  }

  /// Clear all cached controllers
  void clearCache() {
    for (final item in _controllerCache.values) {
      _disposeController(item.controller);
    }
    _controllerCache.clear();
  }

  /// Cleanup expired or excess controllers
  void _cleanupCache() {
    // Remove if too many
    if (_controllerCache.length > _maxCachedControllers) {
      // Sort by last used
      final sortedEntries = _controllerCache.entries.toList()
        ..sort((a, b) => a.value.lastUsed.compareTo(b.value.lastUsed));

      // Remove oldest
      final toRemove =
          sortedEntries.take(sortedEntries.length - _maxCachedControllers);

      for (final entry in toRemove) {
        _disposeController(entry.value.controller);
        _controllerCache.remove(entry.key);
      }
    }
  }

  /// Properly dispose of a controller
  void _disposeController(WebViewController controller) {
    try {
      controller.loadRequest(Uri.parse('about:blank'));
    } catch (e) {
      debugPrint('Error clearing webview: $e');
    }
  }
}

/// Helper class to store WebViewController with metadata
class _CachedController {
  final WebViewController controller;
  DateTime lastUsed;

  _CachedController({
    required this.controller,
    required this.lastUsed,
  });
}
