import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carbon_chain/services/auth_service.dart';
import 'package:carbon_chain/screens/otp_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role; // 'driver' or 'admin'
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _isAdmin => widget.role == 'admin';
  Color get _roleColor => _isAdmin ? Colors.blueAccent : const Color(0xFF1DB954);
  String get _roleLabel => _isAdmin ? 'Fleet Owner' : 'Driver';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.sendOtp('+91$phone');
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpScreen(phone: '+91$phone', role: widget.role),
      ));
    } on Exception catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } catch (e) {
      setState(() => _error = 'Failed to send OTP. Check your number and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String msg) {
    if (msg.contains('Twilio') || msg.contains('provider')) {
      return 'SMS service not configured. Contact support.';
    }
    if (msg.contains('rate')) return 'Too many attempts. Wait a minute.';
    if (msg.contains('invalid')) return 'Invalid phone number format.';
    return 'Failed to send OTP. Try again.';
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
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 20),
                  padding: EdgeInsets.zero,
                ),
              ),
              const Spacer(),

              // Role badge
              Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _roleColor.withOpacity(0.3)),
                ),
                child: Text(_roleLabel, style: TextStyle(color: _roleColor, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(height: 20),

              const Center(child: Text('Enter Phone Number', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              const Center(child: Text('We\'ll send you a 4-digit OTP', style: TextStyle(color: Colors.white54, fontSize: 14))),
              const SizedBox(height: 36),

              // Phone input
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _error != null ? Colors.red.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: const Text('+91', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
                    decoration: const InputDecoration(
                      hintText: '00000 00000',
                      hintStyle: TextStyle(color: Colors.white24, letterSpacing: 2),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _sendOtp(),
                  )),
                ]),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ]),
              ],
              const SizedBox(height: 24),

              SizedBox(height: 56, child: ElevatedButton(
                onPressed: _loading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _roleColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                    : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
