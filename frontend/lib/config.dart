import 'package:flutter/foundation.dart';

class Config {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 is the special alias to your host loopback interface (localhost)
      // on the Android emulator.
      return 'http://10.0.2.2:5000';
    } else {
      // For iOS Simulator, macOS, Windows, localhost works fine.
      return 'http://localhost:5000';
    }
  }
  
  // Helper to get full API URL
  static String get apiUrl => '$baseUrl/api';
}
