import 'dart:async';

import 'package:flutter/foundation.dart';

/// Utility class for optimizing performance related operations
class PerformanceOptimizer {
  /// Map to store last execution time for throttled functions
  static final Map<String, DateTime> _lastExecutionTime = {};

  /// Map to store debounce timers
  static final Map<String, Timer> _debounceTimers = {};

  /// Map to track operation completion status
  static final Map<String, Completer<bool>> _operationCompleters = {};

  /// Prevents multiple executions of a function within specified duration
  /// Returns a Future<bool> that completes with:
  /// - true if the function was executed
  /// - false if the function execution was skipped
  static Future<bool> throttle(
    Future<void> Function() callback, {
    required String key,
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    // Check if there's an ongoing operation with this key
    if (_operationCompleters.containsKey(key) &&
        !_operationCompleters[key]!.isCompleted) {
      debugPrint(
          '🔄 PerformanceOptimizer: Skipping duplicate operation for key: $key');
      return false;
    }

    final now = DateTime.now();

    // Check if enough time has passed since last execution
    if (_lastExecutionTime.containsKey(key)) {
      final lastExecution = _lastExecutionTime[key]!;
      final elapsed = now.difference(lastExecution);

      if (elapsed < duration) {
        debugPrint(
            '🔄 PerformanceOptimizer: Throttling operation for key: $key, try again after ${duration.inMilliseconds - elapsed.inMilliseconds}ms');
        return false;
      }
    }

    // Create a completer to track this operation
    final completer = Completer<bool>();
    _operationCompleters[key] = completer;

    // Update last execution time
    _lastExecutionTime[key] = now;

    try {
      // Execute the callback
      await callback();

      // Mark operation as successfully completed
      if (!completer.isCompleted) completer.complete(true);
      return true;
    } catch (e) {
      debugPrint('❌ PerformanceOptimizer: Error in throttled function: $e');

      // Mark operation as completed with error
      if (!completer.isCompleted) completer.completeError(e);
      rethrow;
    } finally {
      // Clean up after a delay
      Timer(const Duration(seconds: 5), () {
        if (_operationCompleters.containsKey(key)) {
          _operationCompleters.remove(key);
        }
      });
    }
  }

  /// Delays function execution until after wait duration
  /// Resets timer if function is called again during wait period
  static Future<void> debounce(
    Future<void> Function() callback, {
    required String key,
    Duration duration = const Duration(milliseconds: 300),
    bool immediate = false,
  }) async {
    // Cancel previous timer if it exists
    _debounceTimers[key]?.cancel();

    final completer = Completer<void>();

    // Create a new timer
    _debounceTimers[key] = Timer(duration, () async {
      try {
        // Execute callback
        await callback();
        if (!completer.isCompleted) completer.complete();
      } catch (e) {
        debugPrint('❌ PerformanceOptimizer: Error in debounced function: $e');
        if (!completer.isCompleted) completer.completeError(e);
      } finally {
        // Clean up
        if (_debounceTimers.containsKey(key)) {
          _debounceTimers.remove(key);
        }
      }
    });

    return completer.future;
  }

  /// Cancels any pending debounce timer for the given key
  static void cancelDebounce(String key) {
    if (_debounceTimers.containsKey(key)) {
      _debounceTimers[key]?.cancel();
      _debounceTimers.remove(key);
    }
  }

  /// Applies a timeout to a Future
  static Future<T> withTimeout<T>(
    Future<T> future,
    Duration timeout,
    String operation, {
    T? fallbackValue,
  }) {
    return future.timeout(
      timeout,
      onTimeout: () {
        debugPrint(
            '⚠️ PerformanceOptimizer: Operation "$operation" timed out after ${timeout.inMilliseconds}ms');
        if (fallbackValue != null) {
          return fallbackValue;
        }
        throw TimeoutException('Operation "$operation" timed out', timeout);
      },
    );
  }
}
