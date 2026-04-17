
import 'package:flutter/material.dart';
import 'package:carbon_chain/services/auth_service.dart';
import 'package:carbon_chain/services/trip_api_service.dart';
import 'package:carbon_chain/screens/role_select_screen.dart';
import 'package:carbon_chain/screens/owner_profile_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = TripApiService();

  Map<String, dynamic>? _profile;
  Map<String, dynamic> _fleetStats = {'day': 0.0, 'week': 0.0, 'month': 0.0, 'annual': 0.0};
  List<Map<String, dynamic>> _driverStats = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  Map<String, dynamic> _analytics = {};
  bool _loading = true;
  int _selectedPeriod = 1;
  final _periods = ['Day', 'Week', 'Month', 'Annual'];
  final _periodKeys = ['day', 'week', 'month', 'annual'];
  final _periodApiKeys = ['day', 'week', 'month', 'annual'];

  // AI Assistant
  bool _showAssistant = false;
  final List<Map<String, String>> _chatMessages = [];
  final _chatController = TextEditingController();
  bool _chatLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
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
        _api.getFleetAnalytics(companyId: companyId, period: _periodApiKeys[_selectedPeriod]),
      ]);
      setState(() {
        _fleetStats = results[0] as Map<String, dynamic>;
        _driverStats = results[1] as List<Map<String, dynamic>>;
        _pendingRequests = results[2] as List<Map<String, dynamic>>;
        _analytics = results[3] as Map<String, dynamic>;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendChat(String message) async {
    if (message.trim().isEmpty) return;
    _chatController.clear();
    setState(() {
      _chatMessages.add({'role': 'user', 'content': message});
      _chatLoading = true;
    });

    // Build rich fleet context with all available data
    final period = _periods[_selectedPeriod];
    final key = _currentKey;

    final driverLines = _driverStats.map((d) {
      final co2 = (d[key] as num?)?.toDouble() ?? 0.0;
      return '  - ${d['name'] ?? 'Unknown'} | Truck: ${d['truck_number'] ?? '—'} | Location: ${d['location'] ?? '—'} | CO₂ ($period): ${co2.toStringAsFixed(1)} kg';
    }).join('\n');

    final overspeedEvents = (_analytics['overspeedingEvents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final overspeedLines = overspeedEvents.isEmpty
        ? '  None'
        : overspeedEvents.map((e) => '  - ${e['driverName']} on ${e['date']} at ${e['time']}: ${e['maxSpeed']} km/h (Truck: ${e['truckNumber']})').join('\n');

    final pendingLines = _pendingRequests.isEmpty
        ? '  None'
        : _pendingRequests.map((r) {
            final d = r['profiles'] as Map? ?? {};
            return '  - ${d['name'] ?? 'Unknown'} | Phone: ${d['phone'] ?? '—'} | Truck: ${d['truck_number'] ?? '—'}';
          }).join('\n');

    final context = '''
Fleet: ${_profile?['name'] ?? 'Unknown Company'}
Owner: ${_profile?['name'] ?? '—'}
Period: $period

CO₂ Stats:
  Day: ${(_fleetStats['day'] as num?)?.toStringAsFixed(1) ?? '0'} kg
  Week: ${(_fleetStats['week'] as num?)?.toStringAsFixed(1) ?? '0'} kg
  Month: ${(_fleetStats['month'] as num?)?.toStringAsFixed(1) ?? '0'} kg
  Annual: ${(_fleetStats['annual'] as num?)?.toStringAsFixed(1) ?? '0'} kg

Total Trips ($period): ${_analytics['tripCount'] ?? 0}
Avg CO₂/Trip: ${(_analytics['avgCarbon'] as num?)?.toStringAsFixed(1) ?? '0'} kg
Top Emitter: ${_analytics['topEmitter'] ?? 'N/A'}

Active Drivers (${_driverStats.length}):
$driverLines

Overspeeding Events (${overspeedEvents.length}):
$overspeedLines

Pending Join Requests (${_pendingRequests.length}):
$pendingLines
''';

    final reply = await _api.chatWithAssistant(messages: _chatMessages, fleetContext: context);
    setState(() {
      _chatMessages.add({'role': 'assistant', 'content': reply});
      _chatLoading = false;
    });
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
    final overspeedEvents = (_analytics['overspeedingEvents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final aiInsights = _analytics['aiInsights'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _showAssistant = !_showAssistant),
        backgroundColor: Colors.blueAccent,
        child: Icon(_showAssistant ? Icons.close : Icons.smart_toy_outlined),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.business, color: Colors.blueAccent, size: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Fleet Dashboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(_profile?['name'] as String? ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ])),
                    if (_pendingRequests.isNotEmpty)
                      Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)), child: Text('${_pendingRequests.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                    IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerProfileScreen())).then((_) => _load()), icon: const Icon(Icons.person_outline, color: Colors.white54)),
                  ]),
                ),

                // Period selector
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: List.generate(4, (i) => Expanded(child: GestureDetector(
                      onTap: () { setState(() => _selectedPeriod = i); _load(); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(color: _selectedPeriod == i ? Colors.blueAccent : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                        child: Text(_periods[i], textAlign: TextAlign.center, style: TextStyle(color: _selectedPeriod == i ? Colors.white : Colors.white54, fontWeight: FontWeight.w600, fontSize: 12)),
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
                    isScrollable: true,
                    tabs: [
                      const Tab(text: 'Analytics'),
                      Tab(text: overspeedEvents.isNotEmpty ? '⚠ Speed (${overspeedEvents.length})' : 'Speed'),
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
                                Text(totalCo2 >= 1000 ? '${(totalCo2 / 1000).toStringAsFixed(2)} t' : '${totalCo2.toStringAsFixed(1)} kg', style: TextStyle(color: _co2Color(totalCo2), fontSize: 42, fontWeight: FontWeight.bold)),
                                Text('CO₂ — ${_periods[_selectedPeriod]}', style: TextStyle(color: _co2Color(totalCo2).withOpacity(0.7), fontSize: 13)),
                              ]),
                            ),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _StatBox(label: 'Drivers', value: '${_driverStats.length}', icon: Icons.people_outline, color: Colors.blueAccent)),
                              const SizedBox(width: 12),
                              Expanded(child: _StatBox(label: 'Trips', value: '${_analytics['tripCount'] ?? 0}', icon: Icons.route, color: Colors.teal)),
                              const SizedBox(width: 12),
                              Expanded(child: _StatBox(label: 'Overspeed', value: '${overspeedEvents.length}', icon: Icons.speed, color: overspeedEvents.isNotEmpty ? Colors.red : Colors.white38)),
                            ]),
                            // AI Fleet Insights
                            if (aiInsights.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3))),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [const Icon(Icons.auto_awesome, color: Color(0xFF1DB954), size: 16), const SizedBox(width: 8), const Text('AI Fleet Insights', style: TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold, fontSize: 13))]),
                                  const SizedBox(height: 10),
                                  Text(aiInsights, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.6)),
                                ]),
                              ),
                            ],
                          ]),
                        ),
                      ),

                      // ── Overspeeding Tab ──
                      overspeedEvents.isEmpty
                          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.check_circle_outline, color: Color(0xFF1DB954), size: 48),
                              SizedBox(height: 12),
                              Text('No overspeeding events', style: TextStyle(color: Colors.white54)),
                              SizedBox(height: 4),
                              Text('All drivers within speed limits', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            ]))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: overspeedEvents.length,
                              itemBuilder: (_, i) {
                                final e = overspeedEvents[i];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))),
                                  child: Row(children: [
                                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.speed, color: Colors.red, size: 20)),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(e['driverName'] as String? ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                      Text('${e['date']} at ${e['time']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                      Text('Truck: ${e['truckNumber'] ?? '—'}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                    ])),
                                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Text('${(e['maxSpeed'] as num?)?.toStringAsFixed(0) ?? '—'}', style: const TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold)),
                                      const Text('km/h', style: TextStyle(color: Colors.red, fontSize: 10)),
                                    ]),
                                  ]),
                                );
                              },
                            ),

                      // ── Drivers Table Tab ──
                      _loading
                          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                          : _driverStats.isEmpty
                              ? const Center(child: Text('No drivers yet', style: TextStyle(color: Colors.white38)))
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                      child: const Row(children: [
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
                                        decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.06))),
                                        child: Row(children: [
                                          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(d['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                            Text(d['location'] as String? ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                          ])),
                                          Expanded(flex: 2, child: Text(d['truck_number'] as String? ?? '—', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                          Expanded(flex: 2, child: Text(co2 >= 1000 ? '${(co2 / 1000).toStringAsFixed(1)}t' : '${co2.toStringAsFixed(1)}kg', style: TextStyle(color: _co2Color(co2), fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
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
                                  decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange.withOpacity(0.2))),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [const Icon(Icons.person_outline, color: Colors.orange, size: 18), const SizedBox(width: 8), Text(driver['name'] as String? ?? 'Driver', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))]),
                                    const SizedBox(height: 4),
                                    Text('Phone: ${driver['phone'] ?? '—'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    Text('Truck: ${driver['truck_number'] ?? '—'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    const SizedBox(height: 12),
                                    Row(children: [
                                      Expanded(child: OutlinedButton(onPressed: () async { await AuthService.respondToRequest(req['id'] as String, req['driver_id'] as String, false); _load(); }, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: const Text('Reject'))),
                                      const SizedBox(width: 12),
                                      Expanded(child: ElevatedButton(onPressed: () async { await AuthService.respondToRequest(req['id'] as String, req['driver_id'] as String, true); _load(); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.black), child: const Text('Accept'))),
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

            // ── AI Assistant Panel ──
            if (_showAssistant)
              Positioned(
                bottom: 80, right: 16, left: 16,
                child: Container(
                  height: 380,
                  decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blueAccent.withOpacity(0.3)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)]),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                      child: Row(children: [
                        const Icon(Icons.smart_toy_outlined, color: Colors.blueAccent, size: 18),
                        const SizedBox(width: 8),
                        const Text('AI Fleet Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        GestureDetector(onTap: () => setState(() => _showAssistant = false), child: const Icon(Icons.close, color: Colors.white38, size: 18)),
                      ]),
                    ),
                    Expanded(
                      child: _chatMessages.isEmpty
                          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 32),
                              const SizedBox(height: 8),
                              Text('Ask me about your fleet emissions,\ndrivers, or sustainability tips.', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12), textAlign: TextAlign.center),
                            ]))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _chatMessages.length,
                              itemBuilder: (_, i) {
                                final msg = _chatMessages[i];
                                final isUser = msg['role'] == 'user';
                                return Align(
                                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                                    decoration: BoxDecoration(
                                      color: isUser ? Colors.blueAccent : const Color(0xFF0F1923),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(msg['content'] ?? '', style: TextStyle(color: isUser ? Colors.white : Colors.white.withOpacity(0.85), fontSize: 13)),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (_chatLoading) const LinearProgressIndicator(color: Colors.blueAccent, backgroundColor: Colors.transparent),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(child: TextField(
                          controller: _chatController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Ask about your fleet...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                            filled: true, fillColor: const Color(0xFF0F1923),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: _sendChat,
                        )),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _sendChat(_chatController.text),
                          child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.send, color: Colors.white, size: 18)),
                        ),
                      ]),
                    ),
                  ]),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
      ]),
    );
  }
}
