import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carbon_chain/services/auth_service.dart';
import 'package:carbon_chain/screens/otp_screen.dart';
import 'package:carbon_chain/screens/home_screen.dart';
import 'package:carbon_chain/screens/admin_dashboard_screen.dart';
import 'package:carbon_chain/screens/profile_setup_screen.dart';
import 'package:carbon_chain/screens/pending_approval_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  bool get _isAdmin => widget.role == 'admin';
  Color get _roleColor => _isAdmin ? Colors.blueAccent : const Color(0xFF1DB954);

  void _startCooldown() {
    _cooldownSeconds = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) t.cancel();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Phone OTP ──────────────────────────────────────────────────────────────
  Future<void> _sendPhoneOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.sendOtp('+91$phone');
      if (!mounted) return;
      _startCooldown();
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpScreen(
          phone: '+91$phone',
          role: widget.role,
          isDevNumber: phone == '9369163234',
        ),
      ));
    } catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Email Auth ─────────────────────────────────────────────────────────────
  Future<void> _handleEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      // Always use OTP flow — works for both new and existing users
      await AuthService.signUpWithEmail(email, '');
      if (!mounted) return;
      _startCooldown();
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpScreen(phone: email, role: widget.role, isEmail: true),
      ));
    } catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _routeAfterLogin() async {
    final profile = await AuthService.getProfile();
    if (!mounted) return;
    if (profile == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ProfileSetupScreen(role: widget.role),
      ));
    } else if (profile['role'] == 'admin') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
    } else if (profile['status'] == 'pending') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PendingApprovalScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  String _friendlyError(String msg) {
    if (msg.contains('Twilio') || msg.contains('provider') || msg.contains('SMS')) return 'SMS service not configured. Use email login instead.';
    if (msg.contains('rate')) return 'Too many attempts. Wait a minute.';
    if (msg.contains('Invalid login')) return 'Invalid email or password.';
    if (msg.contains('already registered')) return 'Email already registered. Sign in instead.';
    if (msg.contains('Email not confirmed')) return 'Check your email for the verification OTP.';
    return 'Something went wrong. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 20)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _roleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _roleColor.withOpacity(0.3))),
                  child: Text(_isAdmin ? 'Fleet Owner' : 'Driver', style: TextStyle(color: _roleColor, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Welcome', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Sign in to continue', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
              ]),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(12)),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(color: _roleColor, borderRadius: BorderRadius.circular(10)),
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.white54,
                  dividerColor: Colors.transparent,
                  tabs: const [Tab(text: 'Phone'), Tab(text: 'Email')],
                ),
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Phone Tab ──
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.1))),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1)))),
                            child: const Text('+91', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            autofocus: false,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
                            decoration: const InputDecoration(hintText: '00000 00000', hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16), counterText: ''),
                            onSubmitted: (_) => _sendPhoneOtp(),
                          )),
                        ]),
                      ),
                      if (_error != null && _tabController.index == 0) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(height: 56, child: ElevatedButton(
                        onPressed: (_loading || _cooldownSeconds > 0) ? null : _sendPhoneOtp,
                        style: ElevatedButton.styleFrom(backgroundColor: _roleColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                            : _cooldownSeconds > 0
                                ? Text('Resend in ${_cooldownSeconds}s', style: const TextStyle(fontSize: 15))
                                : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      )),
                    ]),
                  ),

                  // ── Email Tab ──
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SizedBox(height: 16),
                      Text('Enter your email to receive a one-time code', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      _inputField(controller: _emailController, label: 'Email Address', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
                      if (_error != null && _tabController.index == 1) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(height: 56, child: ElevatedButton(
                        onPressed: (_loading || _cooldownSeconds > 0) ? null : _handleEmail,
                        style: ElevatedButton.styleFrom(backgroundColor: _roleColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                            : _cooldownSeconds > 0
                                ? Text('Resend in ${_cooldownSeconds}s', style: const TextStyle(fontSize: 15))
                                : const Text('Send OTP to Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      )),
                      const SizedBox(height: 12),
                      Text('Works for both new and existing accounts', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12), textAlign: TextAlign.center),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({required TextEditingController controller, required String label, required IconData icon, TextInputType keyboard = TextInputType.text, bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
        suffixIcon: suffix,
        filled: true, fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _roleColor)),
      ),
    );
  }
}
