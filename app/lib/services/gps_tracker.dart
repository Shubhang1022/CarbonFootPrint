import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:carbon_chain/utils/haversine.dart';

class GpsTracker {
  StreamSubscription<Position>? _positionSub;

  Position? previousLocation;
  Position? currentLocation;
  double cumulativeDistanceM = 0.0;
  int idleTimeSeconds = 0;
  int ignitionTimeSeconds = 0;
  double currentSpeedKmh = 0.0;

  bool isPaused = false;
  int breakTimeSeconds = 0;
  DateTime? _pausedAt;
  Timer? _ignitionTimer;

  // Rolling speed average (last 3 readings)
  final List<double> _speedBuffer = [];

  DateTime? get pausedAt => _pausedAt;

  // Only accept GPS fixes with accuracy better than this (metres)
  static const double _maxAcceptableAccuracyM = 20.0;
  // Minimum speed (km/h) to count as moving — filters GPS drift
  static const double _movingSpeedThreshold = 3.0;
  // Minimum distance per update to add to cumulative (metres)
  static const double _minDistanceM = 15.0;

  void startTracking() {
    stopTracking();
    previousLocation = null;
    currentLocation = null;
    cumulativeDistanceM = 0.0;
    idleTimeSeconds = 0;
    ignitionTimeSeconds = 0;
    currentSpeedKmh = 0.0;
    isPaused = false;
    breakTimeSeconds = 0;
    _pausedAt = null;
    _speedBuffer.clear();

    _ignitionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isPaused) ignitionTimeSeconds++;
    });

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // OS-level filter: only fire if moved 10m
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPosition, onError: (_) {});
  }

  void _onPosition(Position position) {
    if (isPaused) {
      currentLocation = position;
      return;
    }

    // Reject poor accuracy fixes (GPS drift)
    if (position.accuracy > _maxAcceptableAccuracyM) return;

    // Update speed using GPS-reported speed (m/s → km/h)
    final rawSpeedKmh = (position.speed * 3.6).clamp(0.0, 200.0);
    _speedBuffer.add(rawSpeedKmh);
    if (_speedBuffer.length > 3) _speedBuffer.removeAt(0);
    currentSpeedKmh = _speedBuffer.reduce((a, b) => a + b) / _speedBuffer.length;

    previousLocation = currentLocation;
    currentLocation = position;

    if (previousLocation == null) return;

    final double dist = haversine(previousLocation!, currentLocation!);

    // Only count as moving if BOTH speed AND distance confirm movement
    final bool isMoving = currentSpeedKmh >= _movingSpeedThreshold && dist >= _minDistanceM;

    if (isMoving) {
      cumulativeDistanceM += dist;
    } else {
      // Vehicle is stationary — accumulate idle time
      idleTimeSeconds += 5;
    }
  }

  void pauseTracking() {
    if (!isPaused) {
      isPaused = true;
      _pausedAt = DateTime.now();
    }
  }

  void resumeTracking() {
    if (isPaused) {
      isPaused = false;
      if (_pausedAt != null) {
        breakTimeSeconds += DateTime.now().difference(_pausedAt!).inSeconds;
        _pausedAt = null;
      }
      previousLocation = currentLocation;
    }
  }

  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _ignitionTimer?.cancel();
    _ignitionTimer = null;
  }
}
