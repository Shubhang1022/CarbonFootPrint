import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:carbon_chain/utils/haversine.dart';

class GpsTracker {
  StreamSubscription<Position>? _positionSub;

  Position? previousLocation;
  Position? currentLocation;
  double cumulativeDistanceM = 0.0;
  int idleTimeSeconds = 0;
  int ignitionTimeSeconds = 0; // total trip duration
  double currentSpeedKmh = 0.0;

  bool isPaused = false;
  int breakTimeSeconds = 0;
  DateTime? _pausedAt;
  DateTime? _tripStartTime;
  Timer? _ignitionTimer;

  // Rolling speed average (last 3 readings)
  final List<double> _speedBuffer = [];

  DateTime? get pausedAt => _pausedAt;

  // Speed threshold for idle detection (km/h)
  static const double _idleSpeedThreshold = 5.0;
  // Minimum distance to accept a GPS update (metres)
  static const double _minDistanceFilter = 10.0;

  /// Starts GPS stream tracking.
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
    _tripStartTime = DateTime.now();

    // Ignition timer — ticks every second
    _ignitionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isPaused) ignitionTimeSeconds++;
    });

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // fire every 5m minimum movement
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPosition,
      onError: (_) {}, // retain last known location on error
    );
  }

  void _onPosition(Position position) {
    if (isPaused) {
      currentLocation = position;
      return;
    }

    previousLocation = currentLocation;
    currentLocation = position;

    // Update speed with rolling average
    final rawSpeedKmh = (position.speed * 3.6).clamp(0.0, 200.0);
    _speedBuffer.add(rawSpeedKmh);
    if (_speedBuffer.length > 3) _speedBuffer.removeAt(0);
    currentSpeedKmh = _speedBuffer.reduce((a, b) => a + b) / _speedBuffer.length;

    if (previousLocation == null) return;

    final double dist = haversine(previousLocation!, currentLocation!);

    if (currentSpeedKmh < _idleSpeedThreshold) {
      // Vehicle is idle — accumulate idle time based on time between fixes
      idleTimeSeconds += 5; // approximate 5s per low-speed update
    } else if (dist >= _minDistanceFilter) {
      cumulativeDistanceM += dist;
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
