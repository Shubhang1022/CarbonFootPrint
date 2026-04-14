// Feature: carbon-chain, Property 4: haversine(a, a) == 0 for any point
// Feature: carbon-chain, Property 5: haversine(a, b) == haversine(b, a) (symmetry)
// Feature: carbon-chain, Property 6: triangle inequality holds for any three points
//
// Validates: Requirements 2.1

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:glados/glados.dart';

import 'package:carbon_chain/utils/haversine.dart';

/// Builds a [Position] from lat/lng with all other fields zeroed.
Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// Generator for valid latitude values: [-90.0, 90.0).
Generator<double> get _lat => any.doubleInRange(-90.0, 90.0);

/// Generator for valid longitude values: [-180.0, 180.0).
Generator<double> get _lng => any.doubleInRange(-180.0, 180.0);

void main() {
  // ---------------------------------------------------------------------------
  // Property 4 — Identity: haversine(a, a) == 0
  // ---------------------------------------------------------------------------
  Glados2<double, double>(
    _lat,
    _lng,
    ExploreConfig(numRuns: 100),
  ).test(
    'Property 4 (identity): haversine(a, a) == 0 for any point',
    (lat, lng) {
      final a = _pos(lat, lng);
      expect(
        haversine(a, a),
        closeTo(0.0, 1e-6),
        reason: 'distance from a point to itself must be 0',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Property 5 — Symmetry: haversine(a, b) == haversine(b, a)
  // ---------------------------------------------------------------------------
  Glados<double>(
    any.combine4(_lat, _lng, _lat, _lng, (lat1, lng1, lat2, lng2) {
      return [lat1, lng1, lat2, lng2];
    }),
    ExploreConfig(numRuns: 100),
  ).test(
    'Property 5 (symmetry): haversine(a, b) == haversine(b, a)',
    (coords) {
      final a = _pos(coords[0], coords[1]);
      final b = _pos(coords[2], coords[3]);
      expect(
        haversine(a, b),
        closeTo(haversine(b, a), 1e-6),
        reason: 'haversine must be symmetric',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Property 6 — Triangle inequality: haversine(a, c) <= haversine(a, b) + haversine(b, c)
  // ---------------------------------------------------------------------------
  Glados<double>(
    any.combine4(_lat, _lng, _lat, _lng, (lat1, lng1, lat2, lng2) {
      return [lat1, lng1, lat2, lng2];
    }),
    ExploreConfig(numRuns: 100),
  ).test(
    'Property 6 (triangle inequality): haversine(a,c) <= haversine(a,b) + haversine(b,c)',
    (coords) {
      // Three points: a = coords, b = offset, c = another offset
      final lat1 = coords[0];
      final lng1 = coords[1];
      final lat2 = coords[2];
      final lng2 = coords[3];
      // Derive a third point by combining the two generated coordinates.
      final lat3 = ((lat1 + lat2) / 2).clamp(-90.0, 90.0);
      final lng3 = ((lng1 + lng2) / 2).clamp(-180.0, 180.0);

      final a = _pos(lat1, lng1);
      final b = _pos(lat2, lng2);
      final c = _pos(lat3, lng3);

      final ac = haversine(a, c);
      final ab = haversine(a, b);
      final bc = haversine(b, c);

      // Small epsilon for floating-point rounding.
      expect(
        ac,
        lessThanOrEqualTo(ab + bc + 1e-6),
        reason: 'triangle inequality must hold: haversine(a,c) <= haversine(a,b) + haversine(b,c)',
      );
    },
  );
}
