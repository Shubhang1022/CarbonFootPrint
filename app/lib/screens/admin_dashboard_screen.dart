
import 'package:flutter/material.dart';
import 'package:carbon_chain/services/auth_service.dart';
import 'package:carbon_chain/screens/login_screen.dart';
import 'package:carbon_chain/screens/truck_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _fleetStats = {'day': 0.0, 'week': 0.0, 'month': 0.0, 'annual': 0.0};
  List<Map<String, dynamic>> _truckStats = [];
  bool _loading = true;
  int _selectedPeriod = 0; // 0=day, 1=week, 2=month, 3=annual
  final _periods = ['Day', 'Week', 'Month', 'Annual'];
  final _periodKeys = ['day', 'week', 'month', 'annual'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      AuthService.getFleetStats(),
      AuthService.getTruckStats(),
    ]);
    setState(() {
      _fleetStats = results[0] as Map<String, dynamic>;
      _truckStats = results[1] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  String get _currentKey => _periodKeys[_selectedPeriod];

  Color _carbonColor(double kg) {
    if (kg < 50) return const Color(0xFF1DB954);
    if (kg < 200) return Colors.orange;
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    final totalCo2 = (_fleetStats[_currentKey] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: const Color(0xFF1DB954),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.admin_panel_settings, color: Color(0xFF1DB954), size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Fleet CO₂ Overview', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ])),
                  IconButton(
                    onPressed: () async {
                      await AuthService.signOut();
                      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                    },
                    icon: const Icon(Icons.logout, color: Colors.white54),
                  ),
                ]),
                const SizedBox(height: 20),

                // Period selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: List.generate(4, (i) => Expanded(child: GestureDetector(
                    onTap: () => setState(() => _selectedPeriod = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedPeriod == i ? const Color(0xFF1DB954) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_periods[i], textAlign: TextAlign.center, style: TextStyle(
                        color: _selectedPeriod == i ? Colors.black : Colors.white54,
                        fontWeight: FontWeight.w600, fontSize: 13,
                      )),
                    ),
                  )))),
                ),
                const SizedBox(height: 16),

                // Total fleet CO₂ card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_carbonColor(totalCo2).withOpacity(0.2), _carbonColor(totalCo2).withOpacity(0.05)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _carbonColor(totalCo2).withOpacity(0.4)),
                  ),
                  child: Column(children: [
                    const Icon(Icons.factory_outlined, color: Colors.white70, size: 28),
                    const SizedBox(height: 8),
                    const Text('Total Fleet Emissions', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(
                      totalCo2 >= 1000 ? '${(totalCo2 / 1000).toStringAsFixed(2)} t' : '${totalCo2.toStringAsFixed(1)} kg',
                      style: TextStyle(color: _carbonColor(totalCo2), fontSize: 42, fontWeight: FontWeight.bold),
                    ),
                    Text('CO₂ — ${_periods[_selectedPeriod]}', style: TextStyle(color: _carbonColor(totalCo2).withOpacity(0.7), fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 20),

                // Trucks header
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Vehicles', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${_truckStats.length} trucks', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ]),
                const SizedBox(height: 12),

                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF1DB954))))
                else if (_truckStats.isEmpty)
                  Center(child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(children: [
                      Icon(Icons.local_shipping_outlined, color: Colors.white.withOpacity(0.2), size: 48),
                      const SizedBox(height: 12),
                      const Text('No trucks registered', style: TextStyle(color: Colors.white38)),
                    ]),
                  ))
                else
                  ..._truckStats.map((truck) {
                    final co2 = (truck[_currentKey] as num?)?.toDouble() ?? 0.0;
                    final driverName = (truck['profiles'] as Map?)?['name'] as String? ?? truck['driver_name'] as String? ?? 'Unassigned';
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => TruckDetailScreen(truck: truck),
                      )),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.07)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: _carbonColor(co2).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.local_shipping, color: _carbonColor(co2), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(truck['name'] as String? ?? 'Truck', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('${truck['plate_number'] ?? ''} • $driverName', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(
                              co2 >= 1000 ? '${(co2 / 1000).toStringAsFixed(1)}t' : '${co2.toStringAsFixed(1)}kg',
                              style: TextStyle(color: _carbonColor(co2), fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text('CO₂', style: TextStyle(color: _carbonColor(co2).withOpacity(0.6), fontSize: 10)),
                          ]),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 20),
                        ]),
                      ),
                    );
                  }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
