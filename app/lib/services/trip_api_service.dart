import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TripResult {
  final double carbon;
  final String insights;
  final int efficiencyScore;
  final String moneySavedEstimate;
  final String comparisonToAverage;
  final String nextTripRecommendation;

  const TripResult({
    required this.carbon,
    required this.insights,
    required this.efficiencyScore,
    required this.moneySavedEstimate,
    required this.comparisonToAverage,
    required this.nextTripRecommendation,
  });
}

class TripApiService {
  final String baseUrl;
  final http.Client _client;

  TripApiService({
    this.baseUrl = 'https://carbonfootprint-squc.onrender.com',
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<TripResult> submitTrip({
    required double distance,
    required String fuelType,
    required int idleTime,
    required double loadWeight,
    required double engineEfficiency,
    int ignitionTimeMinutes = 0,
    String language = 'en',
  }) async {
    final uri = Uri.parse('$baseUrl/add-trip');
    final body = jsonEncode({
      'distance': distance,
      'fuel_type': fuelType,
      'idle_time': idleTime,
      'load_weight': loadWeight,
      'engine_efficiency': engineEfficiency,
      'ignition_time': ignitionTimeMinutes,
      'language': language,
    });

    final response = await _client
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TripResult(
        carbon: (json['carbon'] as num).toDouble(),
        insights: json['insights'] as String? ?? '',
        efficiencyScore: (json['efficiencyScore'] as num?)?.toInt() ?? 50,
        moneySavedEstimate: json['moneySavedEstimate'] as String? ?? '',
        comparisonToAverage: json['comparisonToAverage'] as String? ?? '',
        nextTripRecommendation: json['nextTripRecommendation'] as String? ?? '',
      );
    } else {
      throw Exception(response.body);
    }
  }

  Future<String> getCoachingTip({
    required int idleMinutes,
    required double speedKmh,
    required double distanceKm,
    String language = 'en',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/coaching-tip');
      final response = await _client
          .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idle_minutes': idleMinutes,
              'speed_kmh': speedKmh,
              'distance_km': distanceKm,
              'language': language,
            }))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['tip'] as String? ?? '';
      }
    } catch (_) {}
    return '';
  }

  Future<Map<String, dynamic>> getTripHistory({String language = 'en'}) async {
    try {
      final uri = Uri.parse('$baseUrl/trip-history?language=$language');
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'trips': [], 'weeklyAnalysis': ''};
  }
}
