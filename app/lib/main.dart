import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:carbon_chain/screens/home_screen.dart';

void main() {
  // Warm up Render backend on app launch so it's ready when user submits a trip
  _warmUpBackend();
  runApp(const CarbonChainApp());
}

void _warmUpBackend() {
  http.get(Uri.parse('https://carbonfootprint-squc.onrender.com/health'))
      .catchError((_) {}); // fire and forget — ignore errors
}

class CarbonChainApp extends StatelessWidget {
  const CarbonChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarbonChain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1923),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1DB954),
          surface: Color(0xFF1A1F2E),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
