import 'package:flutter/material.dart';
import 'package:carbon_chain/services/auth_service.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});
  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  int _selectedPeriod = 2; // default month
  final _periods = ['Today', 'Week', 'Month'];
  final _periodKeys = ['day', 'week', 'month'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      AuthService.getMyStats(),
      AuthService.getMyTrips(),
    ]);
    setState(() {
      _stats = results[0] as Map<String, dynamic>;
      _trips = results[1] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  Map<String, double> get _currentStats {
    final key = _periodKeys[_selectedPeriod];
    final s = _stats[key] as Map<String, dynamic>? ?? {};
    return {
      'carbon': (s['carbon'] as num?)?.toDouble() ?? 0,
      'distance': (s['distance'] as num?)?.toDouble() ?? 0,
      'idle': (s['idle'] as num?)?.toDouble() ?? 0,
      'trips': (s['trips'] as num?)?.toDouble() ?? 0,
    };
  }

  Color _co2Color(double kg) {
    if (kg < 10) return const Color(0xFF1DB954);
    if (kg < 30) return Colors.orange;
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    final s = _currentStats;

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
                Row(children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 20), padding: EdgeInsets.zero),
                  const Text('My Dashboard', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 20),

                // Period selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: List.generate(3, (i) => Expanded(child: GestureDetector(
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

                if (_loading)
                  const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
                else ...[
                  // Stats grid
                  Row(children: [
                    Expanded(child: _StatCard(icon: Icons.eco, label: 'CO₂ Emitted', value: '${s['carbon']!.toStringAsFixed(1)} kg', color: _co2Color(s['carbon']!))),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.route, label: 'Distance', value: '${s['distance']!.toStringAsFixed(1)} km', color: Colors.blue)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _StatCard(icon: Icons.timer_outlined, label: 'Idle Time', value: '${s['idle']!.toStringAsFixed(0)} min', color: Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.local_shipping_outlined, label: 'Trips', value: '${s['trips']!.toInt()}', color: Colors.purple)),
                  ]),
                  const SizedBox(height: 24),

                  const Text('Trip History', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  if (_trips.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No trips yet', style: TextStyle(color: Colors.white38))))
                  else
                    ..._trips.map((trip) {
                      final carbon = (trip['carbon_kg'] as num?)?.toDouble() ?? 0;
                      final distance = (trip['distance'] as num?)?.toDouble() ?? 0;
                      final idle = (trip['idle_time'] as num?)?.toInt() ?? 0;
                      final date = (trip['created_at'] as String? ?? '').substring(0, 10);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('${distance.toStringAsFixed(1)} km • ${idle}min idle', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${carbon.toStringAsFixed(1)}', style: TextStyle(color: _co2Color(carbon), fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('kg CO₂', style: TextStyle(color: _co2Color(carbon).withOpacity(0.6), fontSize: 10)),
                          ]),
                        ]),
                      );
                    }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
