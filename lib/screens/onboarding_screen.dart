import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../utils/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final List<OnboardingItem> _onboardingItems = [
    OnboardingItem(
      title: 'Welcome to ${AppConstants.appName}',
      description: 'Your complete solution for team attendance management and tracking.',
      animation: 'assets/animations/welcome.json',
      backgroundColor: Colors.blue.shade50,
      textColor: Colors.blue.shade900,
    ),
    OnboardingItem(
      title: 'Track Attendance',
      description: 'Check in and out with ease. Track your team\'s attendance in real-time.',
      animation: 'assets/animations/attendance.json',
      backgroundColor: Colors.green.shade50,
      textColor: Colors.green.shade900,
    ),
    OnboardingItem(
      title: 'Manage Teams',
      description: 'Create teams, add members, and manage permissions all in one place.',
      animation: 'assets/animations/team.json',
      backgroundColor: Colors.purple.shade50,
      textColor: Colors.purple.shade900,
    ),
    OnboardingItem(
      title: 'Generate Reports',
      description: 'Get detailed attendance reports and export them in various formats.',
      animation: 'assets/animations/reports.json',
      backgroundColor: Colors.orange.shade50,
      textColor: Colors.orange.shade900,
    ),
    OnboardingItem(
      title: 'Secure & Reliable',
      description: 'Your data is secure with biometric authentication and cloud backup.',
      animation: 'assets/animations/security.json',
      backgroundColor: Colors.red.shade50,
      textColor: Colors.red.shade900,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _onboardingItems.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    // Save that onboarding is complete
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    
    // Navigate to login screen
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Page view
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _onboardingItems.length,
            itemBuilder: (context, index) {
              final item = _onboardingItems[index];
              return Container(
                color: item.backgroundColor,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Lottie.asset(
                            item.animation,
                            repeat: true,
                            animate: true,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: item.textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              Text(
                                item.description,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: item.textColor.withOpacity(0.8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Skip button
          Positioned(
            top: 48,
            right: 16,
            child: TextButton(
              onPressed: _skipOnboarding,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: _onboardingItems[_currentPage].textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Page indicator and next button
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicator
                  Row(
                    children: List.generate(
                      _onboardingItems.length,
                      (index) => Container(
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 16 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? _onboardingItems[_currentPage].textColor
                              : _onboardingItems[_currentPage].textColor.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  
                  // Next button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _onboardingItems[_currentPage].textColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      _currentPage < _onboardingItems.length - 1 ? 'Next' : 'Get Started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final String animation;
  final Color backgroundColor;
  final Color textColor;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.animation,
    required this.backgroundColor,
    required this.textColor,
  });
}
