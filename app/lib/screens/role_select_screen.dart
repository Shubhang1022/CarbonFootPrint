import 'package:flutter/material.dart';
import 'package:carbon_chain/screens/login_screen.dart';
import 'package:carbon_chain/screens/demo_owner_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

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
              // Logo
              Center(child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.local_shipping, color: Color(0xFF1DB954), size: 56),
              )),
              const SizedBox(height: 24),
              const Center(child: Text('CarbonChain', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))),
              const Center(child: Text('Fleet Emissions Tracker', style: TextStyle(color: Colors.white54, fontSize: 14))),
              const SizedBox(height: 56),

              const Center(child: Text('I am a...', style: TextStyle(color: Colors.white70, fontSize: 16))),
              const SizedBox(height: 20),

              // Driver card
              _RoleCard(
                icon: Icons.drive_eta_outlined,
                title: 'Driver',
                subtitle: 'Track trips and monitor emissions',
                color: const Color(0xFF1DB954),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const LoginScreen(role: 'driver'),
                )),
              ),
              const SizedBox(height: 16),

              // Owner/Admin card
              _RoleCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Fleet Owner',
                subtitle: 'Manage fleet and view dashboard',
                color: Colors.blueAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const LoginScreen(role: 'admin'),
                )),
              ),
              const Spacer(),
              // Demo button
              Center(child: TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DemoOwnerScreen())),
                icon: const Icon(Icons.preview_outlined, size: 16, color: Colors.white38),
                label: const Text('Preview Owner Dashboard (Demo)', style: TextStyle(color: Colors.white38, fontSize: 12)),
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ])),
          Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 16),
        ]),
      ),
    );
  }
}
