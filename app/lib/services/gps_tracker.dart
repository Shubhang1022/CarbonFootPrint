import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:carbon_chain/utils/haversine.dart';

class GpsTracker {
  Timer? _timer;

  final Future<Position> Function() locationProvider;

  Position? previousLocation;
  Position? currentLocation;
  double cumulativeDistanceM = 0.0;
  int idleTimeSeconds = 0;

  /// When paused, GPS still polls but distance/idle accumulation is frozen.
  bool isPaused = false;

  /// Total break time in seconds (paused duration — excluded from idle).
  int breakTimeSeconds = 0;
  DateTime? _pausedAt;

  // Expose for UI live break timer
  DateTime? get pausedAt => _pausedAt;

  GpsTracker({Future<Position> Function()? locationProvider})
      : locationProvider = locationProvider ?? Geolocator.getCurrentPosition;

  void startTracking() {
    stopTracking();
    previousLocation = null;
    currentLocation = null;
    cumulativeDistanceM = 0.0;
    idleTimeSeconds = 0;
    isPaused = false;
    breakTimeSeconds = 0;
    _pausedAt = null;

    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final position = await locationProvider();
        previousLocation = currentLocation;
        currentLocation = position;

        // Skip accumulation while paused
        if (isPaused) return;

        if (previousLocation != null) {
          final double incrementalDistance =
              haversine(previousLocation!, currentLocation!);
          if (incrementalDistance < 5.0) {
            idleTimeSeconds += 5;
          } else {
            cumulativeDistanceM += incrementalDistance;
          }
        }
      } catch (_) {
        // GPS unavailable — retain last known location and continue polling.
      }
    });
  }

  /// Pauses distance/idle accumulation (driver on a break).
  void pauseTracking() {
    if (!isPaused) {
      isPaused = true;
      _pausedAt = DateTime.now();
    }
  }

  /// Resumes accumulation after a break.
  void resumeTracking() {
    if (isPaused) {
      isPaused = false;
      if (_pausedAt != null) {
        breakTimeSeconds += DateTime.now().difference(_pausedAt!).inSeconds;
        _pausedAt = null;
      }
      // Reset previous location so we don't get a huge jump after the break
      previousLocation = currentLocation;
    }
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }
}
