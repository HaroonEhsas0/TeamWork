import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/localization_utils.dart';
import '../providers/theme_provider.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({Key? key}) : super(key: key);

  @override
  _LanguageScreenState createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  Locale? _selectedLocale;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocale();
  }

  Future<void> _loadCurrentLocale() async {
    final locale = await LocalizationUtils.getCurrentLocale();
    setState(() {
      _selectedLocale = locale;
      _isLoading = false;
    });
  }

  Future<void> _changeLanguage(Locale locale) async {
    setState(() {
      _isLoading = true;
    });

    await LocalizationUtils.setCurrentLocale(locale);
    
    setState(() {
      _selectedLocale = locale;
      _isLoading = false;
    });

    // Rebuild the app to apply the new locale
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Language changed to ${LocalizationUtils.getLocaleName(locale)}'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Language Settings'),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                ...LocalizationUtils.supportedLocales.map((locale) {
                  final isSelected = _selectedLocale?.languageCode == locale.languageCode;
                  return _buildLanguageItem(
                    locale: locale,
                    isSelected: isSelected,
                    isDarkMode: isDarkMode,
                  );
                }).toList(),
              ],
            ),
    );
  }

  Widget _buildLanguageItem({
    required Locale locale,
    required bool isSelected,
    required bool isDarkMode,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(
                color: isDarkMode ? Colors.blue.shade400 : Colors.blue.shade700,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _changeLanguage(locale),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Text(
                  LocalizationUtils.getFlagIcon(locale),
                  style: TextStyle(fontSize: 24),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationUtils.getLocaleName(locale),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      locale.languageCode,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: isDarkMode ? Colors.blue.shade400 : Colors.blue.shade700,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
