import 'package:flutter/material.dart';
import 'login_page.dart';

void main() {
  runApp(const SettleApp());
}

class SettleApp extends StatelessWidget {
  const SettleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Settle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C5364),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto', // Default, but explicit is good. 
        // Can add Google Fonts later if user wants specific typography.
      ),
      home: const LoginPage(),
    );
  }
}
