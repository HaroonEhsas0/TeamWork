import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../database_helper.dart';
import '../../services/biometric_service.dart';
import '../../services/service_locator.dart';
import '../../services/auth_cache_service.dart';
import '../../services/auth_service.dart';
import '../../providers/user_provider.dart';
import '../../utils/error_utils.dart';
import '../../widgets/connection_check_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _databaseHelper = DatabaseHelper();
  final BiometricService _biometricService = locator<BiometricService>();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;
  bool _isBiometricAvailable = false;
  bool _rememberMe = false;
  
  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _biometricService.isBiometricAvailable();
      setState(() {
        _isBiometricAvailable = isAvailable;
      });
    } catch (e) {
      print('Error checking biometric availability: $e');
      setState(() {
        _isBiometricAvailable = false;
      });
    }
  }
  
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final hasRememberedUser = prefs.getBool('remember_me') ?? false;
      
      if (savedEmail != null && hasRememberedUser) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    } catch (e) {
      print('Error loading saved credentials: $e');
    }
  }
  
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    try {
      // Get AuthService instance
      final authService = locator<AuthService>();
      
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;
      
      // Sign in with Firebase or offline authentication
      final userCredential = await authService.signInWithEmailAndPassword(email, password);
      
      // Save credentials if remember me is checked
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', email);
        await prefs.setBool('remember_me', true);
        
        // Save user ID for biometric authentication
        if (userCredential.user?.uid != null) {
          await prefs.setString('saved_user_id', userCredential.user!.uid);
          
          // Store credentials securely for biometric auth if available
          if (_isBiometricAvailable) {
            await _biometricService.storeCredentials(email, password);
          }
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('saved_email');
        await prefs.remove('saved_user_id');
        await prefs.setBool('remember_me', false);
        
        // Remove stored credentials
        if (_isBiometricAvailable) {
          await _biometricService.deleteStoredCredentials(email);
        }
      }
      
      // Update last login time
      await AuthCacheService.updateLastLoginTime();
      
      // Check if user is connected to an organization
      final userId = userCredential.user?.uid;
      if (userId != null) {
        // Update user provider with offline fallback support
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.loadUserWithFallback(userId);
        
        final isConnected = await _databaseHelper.isUserConnected(userId);
        if (!isConnected) {
          // Cache that we need to show org code dialog after navigation
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('show_org_code_dialog', true);
        }
      }
      
      // Navigate to home screen - connection check wrapper will handle org code if needed
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      // Use our enhanced error formatting
      final errorMessage = ErrorUtils.formatErrorMessage(e);
      
      setState(() {
        _errorMessage = errorMessage;
      });
      
      // Log error for analytics
      print('Login error: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
      print('Unexpected login error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email to reset password.';
      });
      return;
    }
    
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = 'An error occurred. Please try again.';
      }
      
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _signInWithBiometrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get AuthService instance
      final authService = locator<AuthService>();
      
      // Use the enhanced signInWithBiometrics method
      final userCredential = await authService.signInWithBiometrics();
      
      if (userCredential.user != null) {
        // Get user provider
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        
        // Load user with offline fallback
        await userProvider.loadUserWithFallback(userCredential.user!.uid);
        
        // Navigate to home screen
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _errorMessage = 'Failed to authenticate. Please try again.';
        });
      }
    } on FirebaseAuthException catch (e) {
      // Use our enhanced error formatting
      final errorMessage = ErrorUtils.formatErrorMessage(e);
      
      setState(() {
        _errorMessage = errorMessage;
      });
      
      print('Firebase Auth error during biometric login: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error signing in with biometrics: ${e.toString()}';
      });
      print('Error signing in with biometrics: $e');
    } finally {
  setState(() {
    _isLoading = false;
  });
}

@override
Widget build(BuildContext context) {
  return ConnectionCheckWrapper(
    child: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // App logo or icon
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_alt_rounded,
                        size: 60,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // App Name
                  Text(
                    'TeamWork',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // App Tagline
                  Text(
                    'Manage your team\'s attendance with ease',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 48),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Remember me checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const Text('Remember me'),
                      const Spacer(),
                      TextButton(
                        onPressed: _resetPassword,
                        child: const Text('Forgot Password?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign In'),
                  ),

                  if (_isBiometricAvailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithBiometrics,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.blue.shade700),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(Icons.fingerprint, color: Colors.blue.shade700),
                        label: Text('Sign In with Biometrics', style: TextStyle(color: Colors.blue.shade700)),
                      ),
                    ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Don\'t have an account?'),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Divider(),

                  const SizedBox(height: 16),

                  Text(
                    'TeamWork Attendance',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'v1.0.0',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
