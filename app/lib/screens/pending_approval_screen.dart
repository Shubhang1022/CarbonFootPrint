import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbon_chain/services/auth_service.dart';
import 'package:carbon_chain/screens/home_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  Timer? _pollTimer;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final status = await AuthService.getDriverRequestStatus();
      if (!mounted) return;
      if (status == 'accepted') {
        _pollTimer?.cancel();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else if (status == 'rejected') {
        setState(() => _status = 'rejected');
        _pollTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1923),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_status == 'pending') ...[
                  const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 64),
                  const SizedBox(height: 24),
                  const Text('Waiting for Approval', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text('Your join request has been sent to the fleet owner.\nYou\'ll be notified once approved.', style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  const Center(child: CircularProgressIndicator(color: Colors.amber)),
                ] else ...[
                  const Icon(Icons.cancel_outlined, color: Colors.red, size: 64),
                  const SizedBox(height: 24),
                  const Text('Request Rejected', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text('The fleet owner rejected your request.\nContact them directly or try another company.', style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      await AuthService.signOut();
                      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text('Go Back to Login'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
