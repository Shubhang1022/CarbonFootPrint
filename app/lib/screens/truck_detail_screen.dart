
import 'package:flutter/material.dart';
import 'package:carbon_chain/services/auth_service.dart';

class TruckDetailScreen extends StatefulWidget {
  final Map<String, dynamic> truck;
  const TruckDetailScreen({super.key, required this.truck});

  @override
  State<TruckDetailScreen> createState() => _TruckDetailScreenState();
}

class _TruckDetailScreenState extends State<TruckDetailScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  int _selectedPeriod = 1; // default week
  final _periods = ['Day', 'Week', 'Month', 'Annual'];
  final _periodKeys = ['day', 'week', 'month', 'annual'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final trips = await AuthService.getTruckTrips(widget.truck['id'] as String);
    setState(() { _trips = trips; _loading = false; });
  }

  double get _periodCo2 {
    final key = _periodKeys[_selectedPeriod];
    return (widget.truck[key] as num?)?.toDouble() ?? 0.0;
  }

  Color _carbonColor(double kg) {
    if (kg < 10) return const Color(0xFF1DB954);
    if (kg < 30) return Colors.orange;
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.truck['name'] as String? ?? 'Truck';
    final plate = widget.truck['plate_number'] as String? ?? '';
    final driverName = (widget.truck['profiles'] as Map?)?['name'] as String? ?? 'Unassigned';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), padding: EdgeInsets.zero),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('$plate • $driverName', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
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

              // CO₂ for period
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _carbonColor(_periodCo2).withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.eco, color: _carbonColor(_periodCo2), size: 32),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_periods[_selectedPeriod]} Emissions', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(
                      _periodCo2 >= 1000 ? '${(_periodCo2 / 1000).toStringAsFixed(2)} t CO₂' : '${_periodCo2.toStringAsFixed(1)} kg CO₂',
                      style: TextStyle(color: _carbonColor(_periodCo2), fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),

              const Text('Recent Trips', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              if (_loading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
              else if (_trips.isEmpty)
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
                        Text('${carbon.toStringAsFixed(1)}', style: TextStyle(color: _carbonColor(carbon), fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('kg CO₂', style: TextStyle(color: _carbonColor(carbon).withOpacity(0.6), fontSize: 10)),
                      ]),
                    ]),
                  );
                }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
