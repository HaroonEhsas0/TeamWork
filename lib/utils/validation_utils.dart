class ValidationUtils {
  // Validate email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    
    return null;
  }
  
  // Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }
  
  // Validate strong password
  static String? validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    
    return null;
  }
  
  // Validate name
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    return null;
  }
  
  // Validate phone number
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone number is optional
    }
    
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    
    return null;
  }
  
  // Validate organization code
  static String? validateOrganizationCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Organization code is required';
    }
    
    if (value.length != 6) {
      return 'Organization code must be 6 characters';
    }
    
    return null;
  }
  
  // Validate required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    return null;
  }
  
  // Validate minimum length
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    
    return null;
  }
  
  // Validate maximum length
  static String? validateMaxLength(String? value, int maxLength, String fieldName) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    if (value.length > maxLength) {
      return '$fieldName must be at most $maxLength characters';
    }
    
    return null;
  }
  
  // Validate numeric value
  static String? validateNumeric(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    if (double.tryParse(value) == null) {
      return '$fieldName must be a number';
    }
    
    return null;
  }
  
  // Validate integer value
  static String? validateInteger(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    if (int.tryParse(value) == null) {
      return '$fieldName must be an integer';
    }
    
    return null;
  }
  
  // Validate minimum value
  static String? validateMinValue(String? value, double minValue, String fieldName) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    final numValue = double.tryParse(value);
    if (numValue == null) {
      return '$fieldName must be a number';
    }
    
    if (numValue < minValue) {
      return '$fieldName must be at least $minValue';
    }
    
    return null;
  }
  
  // Validate maximum value
  static String? validateMaxValue(String? value, double maxValue, String fieldName) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    final numValue = double.tryParse(value);
    if (numValue == null) {
      return '$fieldName must be a number';
    }
    
    if (numValue > maxValue) {
      return '$fieldName must be at most $maxValue';
    }
    
    return null;
  }
  
  // Validate URL
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URL is optional
    }
    
    final urlRegex = RegExp(
      r'^(https?:\/\/)?' + // protocol
      r'((([a-z\d]([a-z\d-]*[a-z\d])*)\.)+[a-z]{2,}|' + // domain name
      r'((\d{1,3}\.){3}\d{1,3}))' + // OR ip (v4) address
      r'(\:\d+)?(\/[-a-z\d%_.~+]*)*' + // port and path
      r'(\?[;&a-z\d%_.~+=-]*)?' + // query string
      r'(\#[-a-z\d_]*)?$', // fragment locator
      caseSensitive: false,
    );
    
    if (!urlRegex.hasMatch(value)) {
      return 'Enter a valid URL';
    }
    
    return null;
  }
  
  // Validate date format
  static String? validateDateFormat(String? value, String format) {
    if (value == null || value.isEmpty) {
      return null; // Date is optional
    }
    
    try {
      final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$'); // yyyy-MM-dd
      if (format == 'yyyy-MM-dd' && !dateRegex.hasMatch(value)) {
        return 'Enter a valid date in format $format';
      }
      
      final parts = value.split('-');
      if (parts.length != 3) {
        return 'Enter a valid date in format $format';
      }
      
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      
      if (year == null || month == null || day == null) {
        return 'Enter a valid date in format $format';
      }
      
      if (month < 1 || month > 12) {
        return 'Month must be between 1 and 12';
      }
      
      final daysInMonth = DateTime(year, month + 1, 0).day;
      if (day < 1 || day > daysInMonth) {
        return 'Day must be between 1 and $daysInMonth for the selected month';
      }
      
      return null;
    } catch (e) {
      return 'Enter a valid date in format $format';
    }
  }
  
  // Validate time format
  static String? validateTimeFormat(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Time is optional
    }
    
    final timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$'); // HH:mm
    if (!timeRegex.hasMatch(value)) {
      return 'Enter a valid time in format HH:mm';
    }
    
    return null;
  }
}
