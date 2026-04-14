import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class TripResult {
  final double carbon;
  final String insights;

  const TripResult({required this.carbon, required this.insights});
}

class TripApiService {
  final String baseUrl;
  final http.Client _client;

  TripApiService({
    this.baseUrl = 'http://localhost:3000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<TripResult> submitTrip({
    required double distance,
    required String fuelType,
    required int idleTime,
    required double loadWeight,
    required double engineEfficiency,
  }) async {
    final uri = Uri.parse('$baseUrl/add-trip');
    final body = jsonEncode({
      'distance': distance,
      'fuel_type': fuelType,
      'idle_time': idleTime,
      'load_weight': loadWeight,
      'engine_efficiency': engineEfficiency,
    });

    final response = await _client
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TripResult(
        carbon: (json['carbon'] as num).toDouble(),
        insights: json['insights'] as String? ?? '',
      );
    } else {
      throw Exception(response.body);
    }
  }
}
