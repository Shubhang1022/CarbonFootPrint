
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carbon_chain/services/auth_service.dart';
import 'package:carbon_chain/screens/profile_setup_screen.dart';
import 'package:carbon_chain/screens/home_screen.dart';
import 'package:carbon_chain/screens/admin_dashboard_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  int _resendSeconds = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) { t.cancel(); return; }
      setState(() => _resendSeconds--);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onDigitEntered(int index, String value) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == 4) _verify();
  }

  Future<void> _verify() async {
    if (_otp.length != 4) return;
    setState(() { _loading = true; _error = null; });
    try {
      final success = await AuthService.verifyOtp(widget.phone, _otp);
      if (!mounted) return;
      if (!success) {
        setState(() { _error = 'Invalid OTP. Try again.'; _loading = false; });
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
        return;
      }
      // Check profile
      final profile = await AuthService.getProfile();
      if (!mounted) return;
      if (profile == null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
      } else if (profile['role'] == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Verification failed. Try again.'; _loading = false; });
    }
  }

  Future<void> _resend() async {
    await AuthService.sendOtp(widget.phone);
    _startResendTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.sms_outlined, color: Color(0xFF1DB954), size: 48),
              const SizedBox(height: 20),
              const Text('Enter OTP', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Sent to ${widget.phone}', style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 40),

              // 4 OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => Container(
                  width: 60, height: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _focusNodes[i].hasFocus ? const Color(0xFF1DB954) : Colors.white.withOpacity(0.1), width: 1.5),
                  ),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                    onChanged: (v) => _onDigitEntered(i, v),
                  ),
                )),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),

              if (_loading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),

              const SizedBox(height: 16),
              Center(child: _resendSeconds > 0
                  ? Text('Resend OTP in ${_resendSeconds}s', style: const TextStyle(color: Colors.white38, fontSize: 13))
                  : TextButton(onPressed: _resend, child: const Text('Resend OTP', style: TextStyle(color: Color(0xFF1DB954))))),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
