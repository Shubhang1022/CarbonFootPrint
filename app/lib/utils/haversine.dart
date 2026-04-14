import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Returns the distance in metres between two GPS positions
/// using the Haversine formula.
double haversine(Position a, Position b) {
  const double R = 6371000; // Earth radius in metres

  final double phi1 = a.latitude * pi / 180;
  final double phi2 = b.latitude * pi / 180;
  final double deltaPhi = (b.latitude - a.latitude) * pi / 180;
  final double deltaLambda = (b.longitude - a.longitude) * pi / 180;

  final double sinDeltaPhi = sin(deltaPhi / 2);
  final double sinDeltaLambda = sin(deltaLambda / 2);

  final double x =
      sinDeltaPhi * sinDeltaPhi +
      cos(phi1) * cos(phi2) * sinDeltaLambda * sinDeltaLambda;

  final double c = 2 * atan2(sqrt(x), sqrt(1 - x));

  return R * c;
}
