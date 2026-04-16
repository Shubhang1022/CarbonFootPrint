
import 'package:flutter/material.dart';
import 'package:carbon_chain/services/auth_service.dart';
import 'package:carbon_chain/screens/role_select_screen.dart';
import 'package:carbon_chain/screens/owner_profile_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profile;
  Map<String, dynamic> _fleetStats = {'day': 0.0, 'week': 0.0, 'month': 0.0, 'annual': 0.0};
  List<Map<String, dynamic>> _driverStats = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loading = true;
  int _selectedPeriod = 1;
  final _periods = ['Day', 'Week', 'Month', 'Annual'];
  final _periodKeys = ['day', 'week', 'month', 'annual'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _profile = await AuthService.getProfile();
    final companyId = _profile?['company_id'] as String?;
    if (companyId != null) {
      final results = await Future.wait([
        AuthService.getFleetStats(companyId),
        AuthService.getDriverStats(companyId),
        AuthService.getPendingRequests(companyId),
      ]);
      setState(() {
        _fleetStats = results[0] as Map<String, dynamic>;
        _driverStats = results[1] as List<Map<String, dynamic>>;
        _pendingRequests = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Color _co2Color(double kg) {
    if (kg < 50) return const Color(0xFF1DB954);
    if (kg < 200) return Colors.orange;
    return const Color(0xFFE53935);
  }

  String get _currentKey => _periodKeys[_selectedPeriod];

  @override
  Widget build(BuildContext context) {
    final totalCo2 = (_fleetStats[_currentKey] as num?)?.toDouble() ?? 0.0;
    final companyName = _profile?['companies']?['name'] as String? ?? 'Your Fleet';

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
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Fleet Dashboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(_profile?['name'] as String? ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
                // Pending badge
                if (_pendingRequests.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                    child: Text('${_pendingRequests.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerProfileScreen())).then((_) => _load()),
                  icon: const Icon(Icons.person_outline, color: Colors.white54),
                ),
              ]),
            ),

            // Period selector
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                  Tab(text: _pendingRequests.isNotEmpty ? 'Requests (${_pendingRequests.length})' : 'Requests'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Analytics Tab ──
                  RefreshIndicator(
                    onRefresh: _load,
                    color: Colors.blueAccent,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        // Total CO₂ hero
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_co2Color(totalCo2).withOpacity(0.2), _co2Color(totalCo2).withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _co2Color(totalCo2).withOpacity(0.4)),
                          ),
                          child: Column(children: [
                            const Icon(Icons.factory_outlined, color: Colors.white70, size: 28),
                            const SizedBox(height: 8),
                            const Text('Total Fleet CO₂', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 8),
                            Text(
                              totalCo2 >= 1000 ? '${(totalCo2 / 1000).toStringAsFixed(2)} t' : '${totalCo2.toStringAsFixed(1)} kg',
                              style: TextStyle(color: _co2Color(totalCo2), fontSize: 42, fontWeight: FontWeight.bold),
                            ),
                            Text('CO₂ — ${_periods[_selectedPeriod]}', style: TextStyle(color: _co2Color(totalCo2).withOpacity(0.7), fontSize: 13)),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        // Stats row
                        Row(children: [
                          Expanded(child: _StatBox(label: 'Drivers', value: '${_driverStats.length}', icon: Icons.people_outline, color: Colors.blueAccent)),
                          const SizedBox(width: 12),
                          Expanded(child: _StatBox(label: 'Pending', value: '${_pendingRequests.length}', icon: Icons.pending_outlined, color: Colors.orange)),
                        ]),
                      ]),
                    ),
                  ),

                  // ── Drivers Table Tab ──
                  _loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                      : _driverStats.isEmpty
                          ? const Center(child: Text('No drivers yet', style: TextStyle(color: Colors.white38)))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(children: [
                                // Table header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                  child: Row(children: const [
                                    Expanded(flex: 3, child: Text('Driver', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text('Truck', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text('CO₂', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                                  ]),
                                ),
                                const SizedBox(height: 8),
                                ..._driverStats.map((d) {
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
                                        Text(d['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                        Text(d['location'] as String? ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                      ])),
                                      Expanded(flex: 2, child: Text(d['truck_number'] as String? ?? '—', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                      Expanded(flex: 2, child: Text(
                                        co2 >= 1000 ? '${(co2 / 1000).toStringAsFixed(1)}t' : '${co2.toStringAsFixed(1)}kg',
                                        style: TextStyle(color: _co2Color(co2), fontSize: 14, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.right,
                                      )),
                                    ]),
                                  );
                                }),
                              ]),
                            ),

                  // ── Pending Requests Tab ──
                  _pendingRequests.isEmpty
                      ? const Center(child: Text('No pending requests', style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _pendingRequests.length,
                          itemBuilder: (_, i) {
                            final req = _pendingRequests[i];
                            final driver = req['profiles'] as Map? ?? {};
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
                                  Text(driver['name'] as String? ?? 'Driver', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                ]),
                                const SizedBox(height: 4),
                                Text('Phone: ${driver['phone'] ?? '—'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('Truck: ${driver['truck_number'] ?? '—'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(child: OutlinedButton(
                                    onPressed: () async {
                                      await AuthService.respondToRequest(req['id'] as String, req['driver_id'] as String, false);
                                      _load();
                                    },
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                    child: const Text('Reject'),
                                  )),
                                  const SizedBox(width: 12),
                                  Expanded(child: ElevatedButton(
                                    onPressed: () async {
                                      await AuthService.respondToRequest(req['id'] as String, req['driver_id'] as String, true);
                                      _load();
                                    },
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
