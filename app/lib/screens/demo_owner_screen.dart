import 'package:flutter/material.dart';
import 'package:carbon_chain/screens/role_select_screen.dart';

/// Demo owner dashboard — no auth required, uses mock data for preview.
class DemoOwnerScreen extends StatefulWidget {
  const DemoOwnerScreen({super.key});
  @override
  State<DemoOwnerScreen> createState() => _DemoOwnerScreenState();
}

class _DemoOwnerScreenState extends State<DemoOwnerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPeriod = 1;
  final _periods = ['Day', 'Week', 'Month', 'Annual'];

  // Mock data
  final _fleetStats = {
    'day': 87.4, 'week': 612.8, 'month': 2340.5, 'annual': 28100.0,
  };

  final _drivers = [
    {'name': 'Ravi Kumar',    'truck': 'MH12AB1234', 'day': 18.2, 'week': 127.4, 'month': 489.0, 'annual': 5868.0, 'location': 'Mumbai'},
    {'name': 'Suresh Patel',  'truck': 'GJ05CD5678', 'day': 22.6, 'week': 158.2, 'month': 601.0, 'annual': 7212.0, 'location': 'Ahmedabad'},
    {'name': 'Amit Singh',    'truck': 'DL01EF9012', 'day': 15.8, 'week': 110.6, 'month': 423.0, 'annual': 5076.0, 'location': 'Delhi'},
    {'name': 'Pradeep Yadav', 'truck': 'UP32GH3456', 'day': 30.8, 'week': 216.6, 'month': 827.5, 'annual': 9930.0, 'location': 'Lucknow'},
  ];

  final _pendingRequests = [
    {'name': 'Vikram Sharma', 'phone': '+91 98765 43210', 'truck': 'RJ14IJ7890'},
    {'name': 'Deepak Verma',  'phone': '+91 87654 32109', 'truck': 'MP09KL2345'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _co2Color(double kg) {
    if (kg < 50) return const Color(0xFF1DB954);
    if (kg < 200) return Colors.orange;
    return const Color(0xFFE53935);
  }

  String get _currentKey => _periods[_selectedPeriod].toLowerCase();
  double get _totalCo2 => (_fleetStats[_currentKey] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.business, color: Colors.blueAccent, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Fleet Dashboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('GreenFleet Logistics Pvt. Ltd.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.4))),
                  child: const Text('DEMO', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectScreen())),
                  icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
                ),
              ]),
            ),

            // Period selector
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(12)),
                child: Row(children: List.generate(4, (i) => Expanded(child: GestureDetector(
                  onTap: () => setState(() => _selectedPeriod = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _selectedPeriod == i ? Colors.blueAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_periods[i], textAlign: TextAlign.center, style: TextStyle(
                      color: _selectedPeriod == i ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.w600, fontSize: 12,
                    )),
                  ),
                )))),
              ),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.blueAccent,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.white38,
                tabs: [
                  const Tab(text: 'Analytics'),
                  const Tab(text: 'Drivers'),
                  Tab(text: 'Requests (${_pendingRequests.length})'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Analytics ──
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      // Total CO₂ hero
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_co2Color(_totalCo2).withOpacity(0.2), _co2Color(_totalCo2).withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _co2Color(_totalCo2).withOpacity(0.4)),
                        ),
                        child: Column(children: [
                          const Icon(Icons.factory_outlined, color: Colors.white70, size: 28),
                          const SizedBox(height: 8),
                          const Text('Total Fleet CO₂', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 8),
                          Text(
                            _totalCo2 >= 1000 ? '${(_totalCo2 / 1000).toStringAsFixed(2)} t' : '${_totalCo2.toStringAsFixed(1)} kg',
                            style: TextStyle(color: _co2Color(_totalCo2), fontSize: 42, fontWeight: FontWeight.bold),
                          ),
                          Text('CO₂ — ${_periods[_selectedPeriod]}', style: TextStyle(color: _co2Color(_totalCo2).withOpacity(0.7), fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _StatBox(label: 'Active Drivers', value: '${_drivers.length}', icon: Icons.people_outline, color: Colors.blueAccent)),
                        const SizedBox(width: 12),
                        Expanded(child: _StatBox(label: 'Pending', value: '${_pendingRequests.length}', icon: Icons.pending_outlined, color: Colors.orange)),
                      ]),
                      const SizedBox(height: 16),
                      // AI insight card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.auto_awesome, color: Color(0xFF1DB954), size: 16),
                            const SizedBox(width: 8),
                            const Text('AI Fleet Insight', style: TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold, fontSize: 13)),
                          ]),
                          const SizedBox(height: 10),
                          const Text(
                            '• Pradeep Yadav has the highest CO₂ output this week — consider route optimisation to save ~18 kg CO₂.\n'
                            '• Fleet idle time is 23% above average — driver training could reduce emissions by 12%.\n'
                            '• Switching 2 trucks to CNG could reduce monthly fleet emissions by ~340 kg CO₂.',
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
                          ),
                        ]),
                      ),
                    ]),
                  ),

                  // ── Drivers Table ──
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        child: const Row(children: [
                          Expanded(flex: 3, child: Text('Driver', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Truck No.', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('CO₂', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      ..._drivers.map((d) {
                        final co2 = (d[_currentKey] as num?)?.toDouble() ?? 0.0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(children: [
                            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(d['location'] as String, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ])),
                            Expanded(flex: 2, child: Text(d['truck'] as String, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            Expanded(flex: 2, child: Text(
                              '${co2.toStringAsFixed(1)} kg',
                              style: TextStyle(color: _co2Color(co2), fontSize: 14, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            )),
                          ]),
                        );
                      }),
                    ]),
                  ),

                  // ── Pending Requests ──
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingRequests.length,
                    itemBuilder: (_, i) {
                      final req = _pendingRequests[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange.withOpacity(0.2)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.person_outline, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Text(req['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ]),
                          const SizedBox(height: 4),
                          Text('Phone: ${req['phone']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          Text('Truck: ${req['truck']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: OutlinedButton(
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected (demo)'))),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                              child: const Text('Reject'),
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: ElevatedButton(
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepted (demo)'))),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.black),
                              child: const Text('Accept'),
                            )),
                          ]),
                        ]),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
      ]),
    );
  }
}
