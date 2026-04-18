import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en');
  
  // Persistence fields
  String _lastGuestRoute = 'Welcome'; // 'Welcome' or 'RoleSelection'
  int _lastDashboardIndex = 0;

  // Session state (not persisted)
  bool _hasDismissedWelcome = false;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get lastGuestRoute => _lastGuestRoute;
  int get lastDashboardIndex => _lastDashboardIndex;
  bool get shouldShowWelcome => !_hasDismissedWelcome;

  /// Loads persisted state on startup
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Theme & Locale (example placeholders if you want to extend)
    final themeStr = prefs.getString('themeMode') ?? 'light';
    _themeMode = themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;
    
    final langCode = prefs.getString('languageCode') ?? 'en';
    _locale = Locale(langCode);

    // Navigation Persistence
    _lastDashboardIndex = prefs.getInt('lastDashboardIndex') ?? 0;
    
    notifyListeners();
  }

  void toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', _themeMode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  void setLocale(String languageCode) async {
    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', languageCode);
    notifyListeners();
  }

  /// Saves the last visited guest route (Welcome or RoleSelection)
  Future<void> setLastGuestRoute(String route) async {
    if (_lastGuestRoute == route) return;
    _lastGuestRoute = route;
    // We no longer persist this to SharedPreferences because the user 
    // wants the app to always open the "first page" on startup.
    notifyListeners();
  }

  /// Dismisses the welcome screen for the current session
  void dismissWelcome() {
    _hasDismissedWelcome = true;
    notifyListeners();
  }

  /// Saves the last active dashboard tab index
  Future<void> setLastDashboardIndex(int index) async {
    if (_lastDashboardIndex == index) return;
    _lastDashboardIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastDashboardIndex', index);
  }

  /// Resets persistence on logout
  Future<void> clearPersistence() async {
    _lastGuestRoute = 'Welcome';
    _lastDashboardIndex = 0;
    _hasDismissedWelcome = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastGuestRoute');
    await prefs.remove('lastDashboardIndex');
    notifyListeners();
  }
}
