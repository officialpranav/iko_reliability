import 'package:flutter/material.dart';

///ChangeNotifier for application themes. Used for darkmode and lightmode
class ThemeManager extends ChangeNotifier {
  ThemeManager(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
  }
  ThemeMode _themeMode = ThemeMode.light;

  get themeMode => _themeMode;

  ///controls darkmode/lightmode for the application. Set [isDark] to [true] for darkmode. Notifies all listeners
  toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}