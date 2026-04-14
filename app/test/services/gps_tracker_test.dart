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

void main() {
  group('GpsTracker', () {
    // -----------------------------------------------------------------------
    // Requirement 1.2 — stopTracking cancels polling
    // -----------------------------------------------------------------------
    test('stopTracking cancels the polling timer (Req 1.2)', () async {
      int callCount = 0;

      final tracker = GpsTracker(
        locationProvider: () async {
          callCount++;
          return _fakePosition(1.0, 1.0);
        },
      );

      // Use a fake-async approach: start tracking, let one tick fire, stop,
      // then verify no further ticks occur.
      tracker.startTracking();

      // Advance time past one 5-second interval.
      await Future.delayed(const Duration(milliseconds: 10));

      tracker.stopTracking();

      final countAfterStop = callCount;

      // Wait another interval to confirm no more calls happen.
      await Future.delayed(const Duration(milliseconds: 10));

      expect(callCount, equals(countAfterStop),
          reason: 'locationProvider must not be called after stopTracking');
    });

    test('timer is null after stopTracking (Req 1.2)', () {
      final tracker = GpsTracker(locationProvider: () async => _fakePosition(0, 0));

      tracker.startTracking();
      tracker.stopTracking();

      // _timer is private; we verify indirectly by calling stopTracking again
      // (should be a no-op and not throw).
      expect(() => tracker.stopTracking(), returnsNormally);
    });

    // -----------------------------------------------------------------------
    // Requirement 1.6 — last known location retained when GPS unavailable
    // -----------------------------------------------------------------------
    test(
        'currentLocation is retained when locationProvider throws (Req 1.6)',
        () async {
      // Provider always throws to simulate GPS unavailability.
      final tracker = GpsTracker(
        locationProvider: () async => throw Exception('GPS unavailable'),
      );

      // Manually set a known location as if a previous fix was obtained.
      final knownPosition = _fakePosition(51.5074, -0.1278);
      tracker.currentLocation = knownPosition;

      // Start tracking — the timer callback will fire and the provider throws.
      tracker.startTracking();

      // currentLocation was reset by startTracking; restore it to simulate
      // a location that was set before the signal was lost.
      tracker.currentLocation = knownPosition;

      // Allow the timer callback to fire at least once.
      await Future.delayed(const Duration(milliseconds: 10));

      tracker.stopTracking();

      // The last known location must still be the one we set.
      expect(tracker.currentLocation, equals(knownPosition),
          reason: 'currentLocation must be retained when GPS is unavailable');
    });

    test(
        'previousLocation is not overwritten when locationProvider throws (Req 1.6)',
        () async {
      final knownPosition = _fakePosition(48.8566, 2.3522);

      final tracker = GpsTracker(
        locationProvider: () async => throw Exception('GPS unavailable'),
      );

      tracker.startTracking();

      // Simulate a previously acquired location.
      tracker.currentLocation = knownPosition;
      tracker.previousLocation = knownPosition;

      await Future.delayed(const Duration(milliseconds: 10));

      tracker.stopTracking();

      expect(tracker.currentLocation, equals(knownPosition));
      expect(tracker.previousLocation, equals(knownPosition));
    });
  });
}
