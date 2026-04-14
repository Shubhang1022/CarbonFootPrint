
import 'package:flutter/material.dart';
import 'package:carbon_chain/utils/app_strings.dart';

class ResultScreen extends StatelessWidget {
  final double carbon;
  final double distanceM;
  final int idleTimeSeconds;
  final int ignitionTimeSeconds;
  final int breakTimeSeconds;
  final String insights;
  final String fuelType;
  final double engineEfficiency;
  final int efficiencyScore;
  final String moneySavedEstimate;
  final String comparisonToAverage;
  final bool isHindi;

  const ResultScreen({
    super.key,
    required this.carbon,
    required this.distanceM,
    required this.idleTimeSeconds,
    required this.ignitionTimeSeconds,
    required this.breakTimeSeconds,
    required this.insights,
    required this.fuelType,
    required this.engineEfficiency,
    required this.efficiencyScore,
    required this.moneySavedEstimate,
    required this.comparisonToAverage,
    this.isHindi = false,
  });

  Color get _carbonColor {
    if (carbon < 10) return const Color(0xFF1DB954);
    if (carbon < 30) return Colors.orange;
    return const Color(0xFFE53935);
  }

  Color get _scoreColor {
    if (efficiencyScore >= 70) return const Color(0xFF1DB954);
    if (efficiencyScore >= 40) return Colors.orange;
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(isHindi: isHindi);
    final double distanceKm = distanceM / 1000;
    final int idleMin = idleTimeSeconds ~/ 60;
    final int idleSec = idleTimeSeconds % 60;
    final int ignMin = ignitionTimeSeconds ~/ 60;
    final int ignSec = ignitionTimeSeconds % 60;
    final String carbonRating = carbon < 10 ? s.lowImpact : carbon < 30 ? s.moderate : s.highImpact;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), padding: EdgeInsets.zero),
                const SizedBox(width: 8),
                Text(s.tripSummary, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),

              // Carbon hero
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_carbonColor.withOpacity(0.2), _carbonColor.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _carbonColor.withOpacity(0.4)),
                ),
                child: Column(children: [
                  Icon(Icons.eco, color: _carbonColor, size: 36),
                  const SizedBox(height: 12),
                  Text(carbon.toStringAsFixed(2), style: TextStyle(color: _carbonColor, fontSize: 48, fontWeight: FontWeight.bold)),
                  Text('kg CO₂', style: TextStyle(color: _carbonColor.withOpacity(0.8), fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: _carbonColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text(carbonRating, style: TextStyle(color: _carbonColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Efficiency score bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(14), border: Border.all(color: _scoreColor.withOpacity(0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(s.efficiencyScore, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    Text('$efficiencyScore/100', style: TextStyle(color: _scoreColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                    value: efficiencyScore / 100,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(_scoreColor),
                    minHeight: 8,
                  )),
                  if (comparisonToAverage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(comparisonToAverage, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ],
                  if (moneySavedEstimate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(moneySavedEstimate, style: const TextStyle(color: Color(0xFF1DB954), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
              const SizedBox(height: 12),

              // Stats grid
              Row(children: [
                Expanded(child: _StatCard(icon: Icons.route, label: s.distance, value: '${distanceKm.toStringAsFixed(2)} km', color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(icon: Icons.timer_outlined, label: s.idleTime, value: '${idleMin}m ${idleSec}s', color: idleMin > 5 ? Colors.orange : Colors.teal)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatCard(icon: Icons.key, label: s.ignitionTime, value: '${ignMin}m ${ignSec}s', color: Colors.lightBlue)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(icon: Icons.free_breakfast_outlined, label: s.driverBreak, value: '${breakTimeSeconds ~/ 60}m ${breakTimeSeconds % 60}s', color: Colors.amber)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatCard(icon: Icons.local_gas_station, label: s.fuelType, value: fuelType[0].toUpperCase() + fuelType.substring(1), color: Colors.purple)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(icon: Icons.speed, label: s.engineEff, value: '${engineEfficiency.toStringAsFixed(1)} km/L', color: Colors.cyan)),
              ]),
              const SizedBox(height: 16),

              // AI Insights
              if (insights.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.auto_awesome, color: Color(0xFF1DB954), size: 16)),
                      const SizedBox(width: 10),
                      Text(s.aiInsights, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ]),
                    const SizedBox(height: 14),
                    Text(insights, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.6)),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(height: 56, child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: Text(s.newTrip, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              )),
            ],
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
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
