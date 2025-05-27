import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Import screens and services
import 'database_helper.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/organization_screen.dart';
import 'screens/attendance_history_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/team_management_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/help_screen.dart';
import 'screens/attendance_reports_screen.dart';
import 'screens/messaging_screen.dart';
import 'screens/leave_management_screen.dart';
import 'screens/shift_management_screen.dart';
import 'screens/organization_code_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/connection_check_wrapper.dart';

// Import models and providers
import 'models/user_model.dart';
import 'models/team_model.dart';
import 'models/attendance_model.dart';
import 'models/organization_model.dart';
import 'providers/user_provider.dart';
import 'providers/team_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/organization_provider.dart';
import 'providers/theme_provider.dart';

// Import services
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';
import 'services/biometric_service.dart';
import 'services/service_locator.dart';

// Import utilities
import 'utils/constants.dart';
import 'utils/theme_utils.dart';
import 'utils/date_time_utils.dart';
import 'utils/validation_utils.dart';
import 'utils/ui_utils.dart';
import 'utils/export_utils.dart';
import 'utils/app_utils.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Message received in background: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    print("Firebase initialized successfully");
  } catch (e) {
    print('Failed to initialize Firebase: $e');
    // Continue app initialization - Firebase services will be unavailable
  }

  // Setup service locator
  setupServiceLocator();
  
  // Initialize notification service
  try {
    await locator<NotificationService>().initialize();
    print("Notification service initialized successfully");
  } catch (e) {
    print('Failed to initialize notification service: $e');
  }

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  // Get the FCM token
  String? token = await messaging.getToken();
  print("FCM Token: $token");

  // Listen for foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Received a message: ${message.notification?.title}");
  });
  
  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final themeMode = await ThemeUtils.getThemeMode();
    setState(() {
      _themeMode = themeMode;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: ThemeUtils.getLightTheme(),
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => TeamProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => OrganizationProvider()),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(_themeMode),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppConstants.appName,
            theme: ThemeUtils.getLightTheme(),
            darkTheme: ThemeUtils.getDarkTheme(),
            themeMode: themeProvider.themeMode,
            home: AuthGate(),
            routes: {
              '/login': (context) => LoginScreen(),
              '/register': (context) => RegisterScreen(),
              '/home': (context) => HomeScreen(),
              '/organization': (context) => OrganizationScreen(),
              '/attendance_history': (context) => AttendanceHistoryScreen(),
              '/attendance': (context) => AttendanceScreen(),
              '/team_management': (context) => TeamManagementScreen(),
              '/profile': (context) => ProfileScreen(),
              '/settings': (context) => SettingsScreen(),
              '/help': (context) => HelpScreen(),
              '/attendance_reports': (context) => AttendanceReportsScreen(),
              '/messaging': (context) => MessagingScreen(),
              '/leaves': (context) => LeaveManagementScreen(),
              '/shifts': (context) => ShiftManagementScreen(),
              '/onboarding': (context) => OnboardingScreen(),
            },
          );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _checkingOnboarding = true;
  bool _onboardingComplete = false;
  
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }
  
  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    
    setState(() {
      _onboardingComplete = onboardingComplete;
      _checkingOnboarding = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // If still checking onboarding status, show loading
    if (_checkingOnboarding) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // If onboarding not complete, show onboarding screen
    if (!_onboardingComplete) {
      return OnboardingScreen();
    }
    
    // Otherwise, check authentication status
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the snapshot has user data, then they're already signed in
        if (snapshot.hasData) {
          // Check user role and direct to appropriate screen
          return FutureBuilder<Map<String, dynamic>?>(
            future: _databaseHelper.getUserRole(snapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              
              // Check if user is admin and direct accordingly
              final role = roleSnapshot.data?['role'] ?? 'user';
              print('User role: $role');
              
              // Pass the role to MainScreen
              return MainScreen(userRole: role);
            },
          );
        }
        // Otherwise, they're not signed in
        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _orgCodeController = TextEditingController();
  final _orgNameController = TextEditingController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isLoading = false;
  bool _isSignUp = false; // Toggle between sign in and sign up
  bool _isCreatingAdmin = false; // Toggle for admin account creation
  bool _isJoiningOrg = false; // Toggle for joining organization

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _orgCodeController.dispose();
    _orgNameController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Sign in with Firebase
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Check if user is connected to an organization
      final userId = userCredential.user?.uid;
      if (userId != null) {
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
          ),
        ),
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
      home: _showSplash 
          ? SplashScreen() 
          : StreamBuilder<User?>(
              stream: _auth.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasData && snapshot.data != null) {
                  // User is logged in
                  return HomeScreen();
                }
                
                // User is not logged in
                return LoginScreen();
              },
            ),
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/home': (context) => HomeScreen(),
        '/organization': (context) => OrganizationScreen(),
        '/attendance_history': (context) => AttendanceHistoryScreen(),
        '/attendance': (context) => AttendanceScreen(),
        '/team_management': (context) => TeamManagementScreen(),
        '/profile': (context) => ProfileScreen(),
        '/settings': (context) => SettingsScreen(),
        '/help': (context) => HelpScreen(),
        '/attendance_reports': (context) => AttendanceReportsScreen(),
      },
    );
  }
  
  Widget _buildSplashApp() {
    return MaterialApp(
      title: 'TeamWork',
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade700,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_alt_rounded,
                size: 80,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'TeamWork',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Manage your team\'s attendance with ease',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
