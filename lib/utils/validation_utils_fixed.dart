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
    
    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    
    // Check for at least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    
    // Check for at least one digit
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    
    // Check for at least one special character
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
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
      return 'Phone number is required';
    }
    
    // Remove any non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'Enter a valid phone number';
    }
    
    return null;
  }
  
  // Validate organization code
  static String? validateOrganizationCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Organization code is required';
    }
    
    // Organization codes should be 6 characters, uppercase alphanumeric
    final orgCodeRegex = RegExp(r'^[A-Z0-9]{6}$');
    if (!orgCodeRegex.hasMatch(value)) {
      return 'Enter a valid 6-character organization code';
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
      return '$fieldName cannot exceed $maxLength characters';
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
      return '$fieldName cannot exceed $maxValue';
    }
    
    return null;
  }
  
  // Validate URL
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URL is optional
    }
    
    final urlRegex = RegExp(
      r'^(https?:\/\/)?((([a-z\d]([a-z\d-]*[a-z\d])*)\.)+[a-z]{2,}|((\d{1,3}\.){3}\d{1,3}))(\:\d+)?(\/[-a-z\d%_.~+]*)*(\?[;&a-z\d%_.~+=-]*)?(\#[-a-z\d_]*)?$',
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
    
    // Simple date format validation for yyyy-MM-dd
    if (format == 'yyyy-MM-dd') {
      final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (!dateRegex.hasMatch(value)) {
        return 'Enter a valid date in format $format';
      }
      
      // Further validation could be added to check valid month/day ranges
    }
    
    return null;
  }
  
  // Validate time format
  static String? validateTimeFormat(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Time is optional
    }
    
    // Validate HH:mm format
    final timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    if (!timeRegex.hasMatch(value)) {
      return 'Enter a valid time in format HH:MM';
    }
    
    return null;
  }
}
