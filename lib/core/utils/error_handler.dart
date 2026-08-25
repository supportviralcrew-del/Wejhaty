import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Central error handling utility for consistent error reporting
/// and user feedback throughout the app.
class ErrorHandler {
  ErrorHandler._();
  static final ErrorHandler instance = ErrorHandler._();

  /// Log errors in debug mode and report to crash reporting service
  /// (e.g., Firebase Crashlytics) in release mode.
  static void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    bool fatal = false,
  }) {
    if (kDebugMode) {
      debugPrint('❌ Error${context != null ? ' in $context' : ''}: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    } else {
      // In release mode, this would integrate with crash reporting
      // FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }

    if (fatal) {
      // Handle fatal errors appropriately
      debugPrint('💀 Fatal error: $error');
    }
  }

  /// Show user-friendly error message via SnackBar
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    VoidCallback? action,
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        action: action != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: action,
              )
            : null,
      ),
    );
  }

  /// Show success message via SnackBar
  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show info message via SnackBar
  static void showInfoSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Get user-friendly error message from common exceptions
  static String getUserFriendlyMessage(dynamic error) {
    if (error.toString().contains('NetworkException') ||
        error.toString().contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }
    if (error.toString().contains('TimeoutException')) {
      return 'Request timed out. Please try again.';
    }
    if (error.toString().contains('Location')) {
      return 'Unable to get location. Please enable GPS services.';
    }
    if (error.toString().contains('Permission')) {
      return 'Permission denied. Please grant the required permissions.';
    }
    return 'An error occurred. Please try again.';
  }
}
