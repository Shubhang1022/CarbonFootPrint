import 'package:flutter/material.dart';
import 'package:carbon_chain/services/trip_api_service.dart';
import 'package:carbon_chain/utils/app_strings.dart';

class HistoryScreen extends StatefulWidget {
  final bool isHindi;
  const HistoryScreen({super.key, this.isHindi = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = TripApiService();
  List<dynamic> _trips = [];
  String _weeklyAnalysis = '';
  bool _loading = true;

  late AppStrings s;

  @override
  void initState() {
    super.initState();
    s = AppStrings(isHindi: widget.isHindi);
    _load();
  }

  Future<void> _load() async {
    final data = await _api.getTripHistory(language: widget.isHindi ? 'hi' : 'en');
    setState(() {
      _trips = data['trips'] as List<dynamic>? ?? [];
      _weeklyAnalysis = data['weeklyAnalysis'] as String? ?? '';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Text(s.tripHistory, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            if (_loading)
              Expanded(child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF1DB954)),
                  const SizedBox(height: 12),
                  Text(s.loadingHistory, style: TextStyle(color: Colors.white.withOpacity(0.5))),
                ],
              )))
            else if (_trips.isEmpty)
              Expanded(child: Center(child: Text(s.noTrips, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16))))
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Weekly AI analysis
                      if (_weeklyAnalysis.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F2E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.auto_awesome, color: Color(0xFF1DB954), size: 16),
                                const SizedBox(width: 8),
                                Text(s.weeklyAnalysis, style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold, fontSize: 13)),
                              ]),
                              const SizedBox(height: 10),
                              Text(_weeklyAnalysis, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Trip list
                      ..._trips.asMap().entries.map((entry) {
                        final i = entry.key;
                        final trip = entry.value as Map<String, dynamic>;
                        final carbon = (trip['carbon_kg'] as num?)?.toDouble() ?? 0;
                        final distance = (trip['distance'] as num?)?.toDouble() ?? 0;
                        final idle = (trip['idle_time'] as num?)?.toInt() ?? 0;
                        final fuel = trip['fuel_type'] as String? ?? '';
                        final date = trip['created_at'] as String? ?? '';
                        final dateStr = date.length >= 10 ? date.substring(0, 10) : date;

                        Color carbonColor = carbon < 10
                            ? const Color(0xFF1DB954)
                            : carbon < 30 ? Colors.orange : const Color(0xFFE53935);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F2E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.07)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: carbonColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(child: Text('${i + 1}', style: TextStyle(color: carbonColor, fontWeight: FontWeight.bold))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dateStr, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text('${distance.toStringAsFixed(1)} km • ${fuel[0].toUpperCase()}${fuel.substring(1)} • ${idle}min idle',
                                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${carbon.toStringAsFixed(1)}', style: TextStyle(color: carbonColor, fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text('kg CO₂', style: TextStyle(color: carbonColor.withOpacity(0.7), fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
