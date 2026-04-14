import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Requests location permission and shows an error dialog if denied.
///
/// Returns true if permission is granted (granted or whileInUse),
/// false if denied or deniedForever.
Future<bool> requestLocationPermission(BuildContext context) async {
  final permission = await Geolocator.requestPermission();

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Location Required'),
          content: const Text(
            'GPS access is required to track trips',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  return true;
}
