import 'package:flutter/material.dart';

class AppSettingsController {
  AppSettingsController._();

  static final ValueNotifier<bool> darkMode = ValueNotifier<bool>(false);

  static void setDarkMode(bool value) {
    if (darkMode.value == value) return;
    darkMode.value = value;
  }

  static void toggleDarkMode() {
    darkMode.value = !darkMode.value;
  }
}
