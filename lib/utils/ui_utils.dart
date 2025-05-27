import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UIUtils {
  // Show a snackbar
  static void showSnackBar(BuildContext context, String message, {
    Duration duration = const Duration(seconds: 2),
    Color backgroundColor = Colors.black87,
    Color textColor = Colors.white,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: textColor),
        ),
        duration: duration,
        backgroundColor: backgroundColor,
        action: action,
      ),
    );
  }
  
  // Show a success snackbar
  static void showSuccessSnackBar(BuildContext context, String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.green.shade800,
      textColor: Colors.white,
      action: action,
    );
  }
  
  // Show an error snackbar
  static void showErrorSnackBar(BuildContext context, String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.red.shade800,
      textColor: Colors.white,
      action: action,
    );
  }
  
  // Show a warning snackbar
  static void showWarningSnackBar(BuildContext context, String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.orange.shade800,
      textColor: Colors.white,
      action: action,
    );
  }
  
  // Show a loading dialog
  static void showLoadingDialog(BuildContext context, {String message = 'Loading...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }
  
  // Show a confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: confirmColor,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }
  
  // Show a custom dialog
  static Future<T?> showCustomDialog<T>(
    BuildContext context, {
    required Widget content,
    String? title,
    List<Widget>? actions,
  }) async {
    return await showDialog<T>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: title != null ? Text(title) : null,
          content: content,
          actions: actions,
        );
      },
    );
  }
  
  // Show a bottom sheet
  static Future<T?> showAppBottomSheet<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    double initialChildSize = 0.5,
    double minChildSize = 0.25,
    double maxChildSize = 0.9,
  }) async {
    return await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 8, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
  
  // Show a date picker
  static Future<DateTime?> showAppDatePicker(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    return await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
  }
  
  // Show a time picker
  static Future<TimeOfDay?> showAppTimePicker(
    BuildContext context, {
    TimeOfDay? initialTime,
  }) async {
    return await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
  }
  
  // Format currency
  static String formatCurrency(double amount, {String symbol = '\$', int decimalDigits = 2}) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount);
  }
  
  // Format percentage
  static String formatPercentage(double percentage, {int decimalDigits = 1}) {
    final formatter = NumberFormat.percentPattern()
      ..maximumFractionDigits = decimalDigits;
    return formatter.format(percentage / 100);
  }
  
  // Format number with commas
  static String formatNumber(num number, {int decimalDigits = 0}) {
    final formatter = NumberFormat.decimalPattern()
      ..maximumFractionDigits = decimalDigits;
    return formatter.format(number);
  }
  
  // Get initials from name
  static String getInitials(String name) {
    if (name.isEmpty) return '';
    
    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    
    return parts[0][0].toUpperCase() + parts[parts.length - 1][0].toUpperCase();
  }
  
  // Get avatar color from name
  static Color getAvatarColor(String name) {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
    ];
    
    if (name.isEmpty) return colors[0];
    
    final index = name.codeUnits.reduce((a, b) => a + b) % colors.length;
    return colors[index];
  }
  
  // Get status color
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'completed':
      case 'success':
        return Colors.green;
      case 'pending':
      case 'in progress':
      case 'waiting':
        return Colors.orange;
      case 'inactive':
      case 'rejected':
      case 'failed':
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  // Get app bar height
  static double getAppBarHeight(BuildContext context) {
    return AppBar().preferredSize.height;
  }
  
  // Get status bar height
  static double getStatusBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }
  
  // Get screen width
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
  
  // Get screen height
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
  
  // Check if device is in dark mode
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
  
  // Check if device is in portrait mode
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }
  
  // Check if device is a tablet
  static bool isTablet(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600;
  }
}
