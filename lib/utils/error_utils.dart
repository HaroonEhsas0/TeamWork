import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

/// A utility class for handling errors and providing consistent user feedback
class ErrorUtils {
  /// Shows a snackbar with an error message
  static void showErrorSnackBar(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: duration ?? Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Shows a snackbar with a success message
  static void showSuccessSnackBar(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: duration ?? Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Shows a snackbar with an info message
  static void showInfoSnackBar(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        duration: duration ?? Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Shows a loading snackbar with a progress indicator
  static void showLoadingSnackBar(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        duration: duration ?? Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows an error dialog with a title and message
  static Future<void> showErrorDialog(BuildContext context, String title, String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        icon: Icon(Icons.error_outline, color: Colors.red.shade700, size: 36),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Formats an error message for display with improved handling for specific error types
  static String formatErrorMessage(dynamic error) {
    if (error is String) return error;
    
    if (error is FirebaseAuthException) {
      return _formatFirebaseAuthError(error);
    } else if (error is SocketException || error is HttpException) {
      return 'Network error: Please check your internet connection and try again.';
    } else if (error is TimeoutException) {
      return 'Request timed out: The operation took too long to complete. Please try again.';
    } else if (error is PlatformException) {
      return 'System error: ${error.message ?? 'An unknown platform error occurred'}';
    }
    
    return error?.toString() ?? 'An unknown error occurred';
  }
  
  /// Formats Firebase Auth specific errors with user-friendly messages
  static String _formatFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      // Authentication errors
      case 'user-not-found':
        return 'No account found with this email address. Please check your email or sign up.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or reset your password.';
      case 'invalid-email':
        return 'The email address format is invalid. Please enter a valid email.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please try again later or reset your password.';
      case 'operation-not-allowed':
        return 'This sign-in method is not allowed. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials.';
      case 'email-already-in-use':
        return 'This email address is already in use by another account.';
      case 'weak-password':
        return 'The password is too weak. Please use a stronger password with at least 6 characters.';
      case 'network-request-failed':
        return 'Network error: Please check your internet connection and try again.';
      case 'invalid-credential':
        return 'The credentials provided are invalid or have expired.';
      case 'credential-already-in-use':
        return 'These credentials are already associated with a different user account.';
      default:
        return 'Authentication error: ${error.message ?? error.code}';
        return 'Incorrect password. Please try again or reset your password.';
      } else if (errorMessage.contains('invalid-email')) {
        return 'Invalid email format. Please enter a valid email address.';
      } else if (errorMessage.contains('weak-password')) {
        return 'Password is too weak. Please use a stronger password.';
      } else if (errorMessage.contains('network-request-failed')) {
        return 'Network error. Please check your internet connection and try again.';
      }
    }
    
    // Handle network errors
    if (errorMessage.contains('SocketException') || 
        errorMessage.contains('Connection refused') ||
        errorMessage.contains('Network is unreachable')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    
    // Handle database errors
    if (errorMessage.contains('DatabaseException')) {
      if (errorMessage.contains('UNIQUE constraint failed')) {
        return 'This record already exists. Please try again with different data.';
      }
      return 'Database error. Please try again later.';
    }
    
    // Simplify error message if it's too technical
    if (errorMessage.length > 100) {
      return 'An error occurred. Please try again or contact support if the issue persists.';
    }
    
    return errorMessage;
  }

  /// Logs an error to the console and optionally to an error reporting service
  static void logError(String tag, dynamic error, StackTrace? stackTrace) {
    print('ERROR [$tag]: $error');
    if (stackTrace != null) {
      print('STACK TRACE: $stackTrace');
    }
    
    // TODO: Add integration with an error reporting service like Firebase Crashlytics
  }
}
