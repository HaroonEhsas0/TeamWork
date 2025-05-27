import 'package:intl/intl.dart';

class DateTimeUtils {
  // Format date to string
  static String formatDate(DateTime date, {String format = 'yyyy-MM-dd'}) {
    return DateFormat(format).format(date);
  }
  
  // Format time to string
  static String formatTime(DateTime time, {String format = 'HH:mm'}) {
    return DateFormat(format).format(time);
  }
  
  // Format date and time to string
  static String formatDateTime(DateTime dateTime, {String format = 'yyyy-MM-dd HH:mm'}) {
    return DateFormat(format).format(dateTime);
  }
  
  // Parse string to date
  static DateTime? parseDate(String dateStr, {String format = 'yyyy-MM-dd'}) {
    try {
      return DateFormat(format).parse(dateStr);
    } catch (e) {
      print('Error parsing date: $e');
      return null;
    }
  }
  
  // Parse string to date time
  static DateTime? parseDateTime(String dateTimeStr, {String format = 'yyyy-MM-dd HH:mm'}) {
    try {
      return DateFormat(format).parse(dateTimeStr);
    } catch (e) {
      print('Error parsing date time: $e');
      return null;
    }
  }
  
  // Get start of day
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
  
  // Get end of day
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }
  
  // Get start of week (Monday)
  static DateTime startOfWeek(DateTime date) {
    final day = date.weekday;
    return DateTime(date.year, date.month, date.day - (day - 1));
  }
  
  // Get end of week (Sunday)
  static DateTime endOfWeek(DateTime date) {
    final day = date.weekday;
    return DateTime(date.year, date.month, date.day + (7 - day), 23, 59, 59, 999);
  }
  
  // Get start of month
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }
  
  // Get end of month
  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
  }
  
  // Get days in month
  static int daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }
  
  // Check if two dates are the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
  
  // Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return isSameDay(date, now);
  }
  
  // Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return isSameDay(date, yesterday);
  }
  
  // Check if date is tomorrow
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(Duration(days: 1));
    return isSameDay(date, tomorrow);
  }
  
  // Get relative time string (e.g. "2 hours ago", "Just now", etc.)
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
  
  // Format duration to string (e.g. "2h 30m")
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
  
  // Format duration to full string (e.g. "2 hours 30 minutes")
  static String formatDurationFull(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours} ${hours == 1 ? 'hour' : 'hours'} ${minutes} ${minutes == 1 ? 'minute' : 'minutes'}';
    } else {
      return '${minutes} ${minutes == 1 ? 'minute' : 'minutes'}';
    }
  }
  
  // Get time of day from DateTime
  static String getTimeOfDay(DateTime dateTime) {
    final hour = dateTime.hour;
    
    if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }
  
  // Get day of week name
  static String getDayOfWeekName(DateTime dateTime) {
    final weekday = dateTime.weekday;
    
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }
  
  // Get month name
  static String getMonthName(DateTime dateTime) {
    final month = dateTime.month;
    
    switch (month) {
      case 1:
        return 'January';
      case 2:
        return 'February';
      case 3:
        return 'March';
      case 4:
        return 'April';
      case 5:
        return 'May';
      case 6:
        return 'June';
      case 7:
        return 'July';
      case 8:
        return 'August';
      case 9:
        return 'September';
      case 10:
        return 'October';
      case 11:
        return 'November';
      case 12:
        return 'December';
      default:
        return '';
    }
  }
}
