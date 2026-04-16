import 'package:flutter/material.dart';
import 'package:carbon_chain/services/auth_service.dart';
import 'package:carbon_chain/screens/role_select_screen.dart';
import 'package:carbon_chain/screens/driver_dashboard_screen.dart';
import 'package:carbon_chain/screens/admin_dashboard_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});
  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await AuthService.getProfile();
    setState(() { _profile = p; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 20), padding: EdgeInsets.zero),
                const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 32),
              if (_loading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
              else ...[
                Center(child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.drive_eta, color: Color(0xFF1DB954), size: 36),
                )),
                const SizedBox(height: 16),
                Center(child: Text(_profile?['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                Center(child: Text('Driver', style: TextStyle(color: const Color(0xFF1DB954).withOpacity(0.8), fontSize: 13))),
                const SizedBox(height: 32),
                _InfoTile(icon: Icons.phone_outlined, label: 'Phone', value: _profile?['phone'] as String? ?? '—'),
                _InfoTile(icon: Icons.local_shipping_outlined, label: 'Truck Number', value: _profile?['truck_number'] as String? ?? '—'),
                _InfoTile(icon: Icons.location_on_outlined, label: 'Location', value: _profile?['location'] as String? ?? '—'),
                _InfoTile(icon: Icons.cake_outlined, label: 'Date of Birth', value: _profile?['dob'] as String? ?? '—'),
                const SizedBox(height: 16),

                // Dashboard button
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverDashboardScreen())),
                  icon: const Icon(Icons.dashboard_outlined, size: 18),
                  label: const Text('My Dashboard'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1DB954),
                    side: const BorderSide(color: Color(0xFF1DB954)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                // Switch to owner view — only for dev/admin number
                if (AuthService.currentUser?.phone == '+919369163234')
                  OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService.switchRole('admin');
                      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()), (_) => false);
                    },
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Switch to Owner View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
              ],
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.signOut();
                  if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectScreen()), (_) => false);
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.07))),
      child: Row(children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ]),
      ]),
    );
  }
}
