import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbon_chain/screens/role_select_screen.dart';
import 'package:carbon_chain/screens/home_screen.dart';
import 'package:carbon_chain/screens/admin_dashboard_screen.dart';
import 'package:carbon_chain/screens/profile_setup_screen.dart';
import 'package:carbon_chain/screens/pending_approval_screen.dart';
import 'package:carbon_chain/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://djpppmpbapdydgluirjk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqcHBwbXBiYXBkeWRnbHVpcmprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0OTkxODQsImV4cCI6MjA5MTA3NTE4NH0.1nCCck14CwihvoSJ25fa0SIDv5L9W7UZOdnpsO8tiBk',
  );

  _warmUpBackend();
  runApp(const CarbonChainApp());
}

void _warmUpBackend() {
  http.get(Uri.parse('https://carbonfootprint-squc.onrender.com/health'))
      .catchError((_) {});
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
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _checking = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (!AuthService.isLoggedIn) {
      setState(() { _destination = const RoleSelectScreen(); _checking = false; });
      return;
    }
    final profile = await AuthService.getProfile();
    if (profile == null) {
      setState(() { _destination = const RoleSelectScreen(); _checking = false; });
    } else if (profile['role'] == 'admin') {
      setState(() { _destination = const AdminDashboardScreen(); _checking = false; });
    } else if (profile['status'] == 'pending') {
      setState(() { _destination = const PendingApprovalScreen(); _checking = false; });
    } else {
      setState(() { _destination = const HomeScreen(); _checking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1923),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
      );
    }
    return _destination!;
  }
}
