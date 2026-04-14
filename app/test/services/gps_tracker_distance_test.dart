import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:carbon_chain/services/gps_tracker.dart';

/// Builds a fake [Position] with the given lat/lng (other fields zeroed).
Position _fakePosition(double lat, double lng) => Position(
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

/// Creates a [GpsTracker] that returns positions from [positions] in order.
GpsTracker _trackerFromPositions(List<Position> positions) {
  int index = 0;
  return GpsTracker(
    locationProvider: () async => positions[index++],
  );
}

void main() {
  group('GpsTracker — distance accumulation', () {
    // -----------------------------------------------------------------------
    // Requirement 2.2, 3.1 — sub-5m update: discarded from distance, adds to idle
    // -----------------------------------------------------------------------
    test(
        'sub-5m update is NOT added to cumulative distance (Req 2.2)',
        () async {
      // Two identical positions → 0 m incremental distance (< 5 m).
      final positions = [
        _fakePosition(0.0, 0.0),
        _fakePosition(0.0, 0.0),
      ];

      final tracker = _trackerFromPositions(positions);
      tracker.startTracking();

      // Allow two timer ticks to fire (first sets currentLocation,
      // second computes the incremental distance).
      await Future.delayed(const Duration(milliseconds: 10));

      tracker.stopTracking();

      expect(
        tracker.cumulativeDistanceM,
        equals(0.0),
        reason: 'sub-5m update must not be added to cumulative distance',
      );
    });

    test(
        'sub-5m update increments idle counter by 5 seconds (Req 3.1)',
        () async {
      // Two identical positions → 0 m incremental distance (< 5 m).
      final positions = [
        _fakePosition(0.0, 0.0),
        _fakePosition(0.0, 0.0),
      ];

      final tracker = _trackerFromPositions(positions);
      tracker.startTracking();

      await Future.delayed(const Duration(milliseconds: 10));

      tracker.stopTracking();

      expect(
        tracker.idleTimeSeconds,
        equals(5),
        reason: 'sub-5m update must increment idle counter by 5 seconds',
      );
    });

    // -----------------------------------------------------------------------
    // Requirement 2.3, 3.2 — >= 5m update: added to distance, idle unchanged
    // -----------------------------------------------------------------------
    test(
        '>= 5m update IS added to cumulative distance (Req 2.3)',
        () async {
      // 0.0001 degree latitude difference ≈ 11 m (well above 5 m threshold).
      final positions = [
        _fakePosition(0.0, 0.0),
        _fakePosition(0.0001, 0.0),
      ];

      final tracker = _trackerFromPositions(positions);
      tracker.startTracking();

      await Future.delayed(const Duration(milliseconds: 10));

      tracker.stopTracking();

      expect(
        tracker.cumulativeDistanceM,
        greaterThan(5.0),
        reason: '>= 5m update must be added to cumulative distance',
      );
    });

    test(
        '>= 5m update does NOT increment idle counter (Req 3.2)',
        () async {
      // 0.0001 degree latitude difference ≈ 11 m.
      final positions = [
        _fakePosition(0.0, 0.0),
        _fakePosition(0.0001, 0.0),
      ];

      final tracker = _trackerFromPositions(positions);
      tracker.startTracking();

      await Future.delayed(const Duration(milliseconds: 10));

      tracker.stopTracking();

      expect(
        tracker.idleTimeSeconds,
        equals(0),
        reason: '>= 5m update must not increment idle counter',
      );
    });

    // -----------------------------------------------------------------------
    // Requirement 2.5, 3.4 — reset on startTracking()
    // -----------------------------------------------------------------------
    test(
        'startTracking() resets cumulative distance to zero (Req 2.5)',
        () async {
      // First trip: accumulate some distance.
      final firstPositions = [
        _fakePosition(0.0, 0.0),
        _fakePosition(0.0001, 0.0),
      ];
      int index = 0;
      final tracker = GpsTracker(
        locationProvider: () async => firstPositions[index++],
      );

      tracker.startTracking();
      await Future.delayed(const Duration(milliseconds: 10));
      tracker.stopTracking();

      // Confirm distance was accumulated.
      expect(tracker.cumulativeDistanceM, greaterThan(0.0));

      // Second trip: startTracking() must reset distance.
      tracker.startTracking();
      tracker.stopTracking();

      expect(
        tracker.cumulativeDistanceM,
        equals(0.0),
        reason: 'startTracking() must reset cumulative distance to zero',
      );
    });

    test(
        'startTracking() resets idle counter to zero (Req 3.4)',
        () async {
      // First trip: accumulate some idle time.
      final firstPositions = [
        _fakePosition(0.0, 0.0),
        _fakePosition(0.0, 0.0),
      ];
      int index = 0;
      final tracker = GpsTracker(
        locationProvider: () async => firstPositions[index++],
      );

      tracker.startTracking();
      await Future.delayed(const Duration(milliseconds: 10));
      tracker.stopTracking();

      // Confirm idle time was accumulated.
      expect(tracker.idleTimeSeconds, equals(5));

      // Second trip: startTracking() must reset idle counter.
      tracker.startTracking();
      tracker.stopTracking();

      expect(
        tracker.idleTimeSeconds,
        equals(0),
        reason: 'startTracking() must reset idle counter to zero',
      );
    });
  });
}
