import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carbon_chain/services/auth_service.dart';
import 'package:carbon_chain/screens/profile_setup_screen.dart';
import 'package:carbon_chain/screens/home_screen.dart';
import 'package:carbon_chain/screens/admin_dashboard_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String role;
  const OtpScreen({super.key, required this.phone, required this.role});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  int _resendSeconds = 30;
  Timer? _resendTimer;

  bool get _isAdmin => widget.role == 'admin';
  Color get _roleColor => _isAdmin ? Colors.blueAccent : const Color(0xFF1DB954);

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  void _startResendTimer() {
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
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
    if (value.isEmpty && index > 0) {
      // Backspace — go back
      _focusNodes[index - 1].requestFocus();
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == 6) {
      Future.delayed(const Duration(milliseconds: 100), _verify);
    }
  }

  Future<void> _verify() async {
    final otp = _otp;
    if (otp.length != 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final success = await AuthService.verifyOtp(widget.phone, otp);
      if (!mounted) return;
      if (!success) {
        setState(() { _error = 'Invalid OTP. Please try again.'; _loading = false; });
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
        return;
      }
      final profile = await AuthService.getProfile();
      if (!mounted) return;
      if (profile == null) {
        // No profile yet — go to setup regardless of reason
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(role: widget.role),
        ));
      } else if (profile['role'] == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on Exception catch (e) {
      if (mounted) setState(() { _error = 'Invalid OTP: ${e.toString()}'; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Verification failed. Try again.'; _loading = false; });
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await AuthService.sendOtp(widget.phone);
      _startResendTimer();
    } catch (_) {
      setState(() => _error = 'Failed to resend. Try again.');
    }
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
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 20),
                  padding: EdgeInsets.zero,
                ),
              ),
              const Spacer(),
              Icon(Icons.sms_outlined, color: _roleColor, size: 48),
              const SizedBox(height: 20),
              const Text('Enter OTP', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Sent to ${widget.phone}', style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 40),

              // 6 OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => Container(
                  width: 46, height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _controllers[i].text.isNotEmpty
                          ? _roleColor
                          : _focusNodes[i].hasFocus
                              ? _roleColor.withOpacity(0.6)
                              : Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: _roleColor, fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                    onChanged: (v) {
                      setState(() {}); // rebuild for border color
                      _onDigitEntered(i, v);
                    },
                  ),
                )),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 14),
                  const SizedBox(width: 6),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ]),
              ],
              const SizedBox(height: 24),

              if (_loading)
                Center(child: CircularProgressIndicator(color: _roleColor)),

              const SizedBox(height: 16),
              Center(child: _resendSeconds > 0
                  ? Text('Resend OTP in ${_resendSeconds}s', style: const TextStyle(color: Colors.white38, fontSize: 13))
                  : TextButton(
                      onPressed: _resend,
                      child: Text('Resend OTP', style: TextStyle(color: _roleColor)),
                    )),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
