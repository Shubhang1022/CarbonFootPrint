import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:carbon_chain/screens/result_screen.dart';
import 'package:carbon_chain/screens/home_screen.dart';
import 'package:carbon_chain/services/gps_tracker.dart';
import 'package:carbon_chain/services/trip_api_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeGpsTracker extends GpsTracker {
  _FakeGpsTracker()
      : super(locationProvider: () async => Position(
              latitude: 0,
              longitude: 0,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            ));

  @override
  void startTracking() {
    cumulativeDistanceM = 0.0;
    idleTimeSeconds = 0;
  }

  @override
  void stopTracking() {}
}

class _FakeTripApiService extends TripApiService {
  final Future<double> Function() submitFn;

  _FakeTripApiService(this.submitFn);

  @override
  Future<double> submitTrip({
    required double distance,
    required String fuelType,
    required int idleTime,
    required double loadWeight,
  }) =>
      submitFn();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildResultScreen({
  double carbon = 27.5,
  double distanceM = 5000,
  int idleTimeSeconds = 120,
}) {
  return MaterialApp(
    home: ResultScreen(
      carbon: carbon,
      distanceM: distanceM,
      idleTimeSeconds: idleTimeSeconds,
    ),
  );
}

Widget _buildHomeScreenWithNav({
  required _FakeTripApiService apiService,
  _FakeGpsTracker? tracker,
}) {
  return MaterialApp(
    home: HomeScreen(
      tracker: tracker ?? _FakeGpsTracker(),
      permissionChecker: (_) async => true,
      apiService: apiService,
    ),
  );
}

Future<void> _startTrip(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Diesel').last);
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField), '500');
  await tester.tap(find.widgetWithText(ElevatedButton, 'Start Trip'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// ResultScreen tests (Req 8.1, 8.2, 8.3, 8.4, 8.5)
// ---------------------------------------------------------------------------

void main() {
  group('ResultScreen — display values', () {
    testWidgets('displays distance in km (Req 8.1)', (tester) async {
      await tester.pumpWidget(_buildResultScreen(distanceM: 5000));
      expect(find.text('5.00 km'), findsOneWidget);
    });

    testWidgets('displays idle time in minutes (Req 8.2)', (tester) async {
      await tester.pumpWidget(_buildResultScreen(idleTimeSeconds: 120));
      expect(find.text('2 min'), findsOneWidget);
    });

    testWidgets('displays carbon in kg CO₂ (Req 8.3)', (tester) async {
      await tester.pumpWidget(_buildResultScreen(carbon: 27.5));
      expect(find.text('27.50 kg CO₂'), findsOneWidget);
    });

    testWidgets('displays all three values simultaneously', (tester) async {
      await tester.pumpWidget(_buildResultScreen(
        distanceM: 10000,
        idleTimeSeconds: 300,
        carbon: 35.0,
      ));
      expect(find.text('10.00 km'), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('35.00 kg CO₂'), findsOneWidget);
    });

    testWidgets('rounds down idle seconds to whole minutes (Req 8.2)', (tester) async {
      await tester.pumpWidget(_buildResultScreen(idleTimeSeconds: 90));
      expect(find.text('1 min'), findsOneWidget);
    });
  });

  group('ResultScreen — New Trip button (Req 8.4, 8.5)', () {
    testWidgets('"New Trip" button is present', (tester) async {
      await tester.pumpWidget(_buildResultScreen());
      expect(find.widgetWithText(ElevatedButton, 'New Trip'), findsOneWidget);
    });

    testWidgets('tapping "New Trip" pops the route (Req 8.4)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ResultScreen(
                  carbon: 10.0,
                  distanceM: 1000,
                  idleTimeSeconds: 60,
                ),
              ),
            ),
            child: const Text('Go to Result'),
          );
        }),
      ));

      await tester.tap(find.text('Go to Result'));
      await tester.pumpAndSettle();

      expect(find.text('10.00 km'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'New Trip'));
      await tester.pumpAndSettle();

      expect(find.text('10.00 km'), findsNothing);
      expect(find.text('Go to Result'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // HomeScreen submission flow tests (Req 5.2, 8.1–8.5)
  // ---------------------------------------------------------------------------

  group('HomeScreen — submission flow', () {
    testWidgets('loading indicator shown while submitting (Req 5.2)', (tester) async {
      final completer = Completer<double>();
      final api = _FakeTripApiService(() => completer.future);

      await tester.pumpWidget(_buildHomeScreenWithNav(apiService: api));
      await _startTrip(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop Trip'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(0.0);
      await tester.pumpAndSettle();
    });

    testWidgets('Stop Trip button disabled while submitting (Req 5.2)', (tester) async {
      final completer = Completer<double>();
      final api = _FakeTripApiService(() => completer.future);

      await tester.pumpWidget(_buildHomeScreenWithNav(apiService: api));
      await _startTrip(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop Trip'));
      await tester.pump();

      final stopBtn = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).last,
      );
      expect(stopBtn.onPressed, isNull);

      completer.complete(0.0);
      await tester.pumpAndSettle();
    });

    testWidgets('on success navigates to ResultScreen with correct values (Req 8.1–8.3)',
        (tester) async {
      final tracker = _FakeGpsTracker()
        ..cumulativeDistanceM = 5000
        ..idleTimeSeconds = 120;

      final api = _FakeTripApiService(() async => 27.5);

      await tester.pumpWidget(_buildHomeScreenWithNav(
        apiService: api,
        tracker: tracker,
      ));
      await _startTrip(tester);

      tracker.cumulativeDistanceM = 5000;
      tracker.idleTimeSeconds = 120;

      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop Trip'));
      await tester.pumpAndSettle();

      expect(find.text('5.00 km'), findsOneWidget);
      expect(find.text('2 min'), findsOneWidget);
      expect(find.text('27.50 kg CO₂'), findsOneWidget);
    });

    testWidgets('on error response shows SnackBar and stays on HomeScreen (Req 5.4)',
        (tester) async {
      final api = _FakeTripApiService(
        () async => throw Exception('Server error'),
      );

      await tester.pumpWidget(_buildHomeScreenWithNav(apiService: api));
      await _startTrip(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop Trip'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Error submitting trip'), findsOneWidget);
      expect(find.text('Status: Stopped'), findsOneWidget);
    });

    testWidgets('on timeout shows timeout SnackBar and stays on HomeScreen (Req 5.5)',
        (tester) async {
      final api = _FakeTripApiService(
        () async => throw TimeoutException('timed out'),
      );

      await tester.pumpWidget(_buildHomeScreenWithNav(apiService: api));
      await _startTrip(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop Trip'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('timed out'), findsOneWidget);
      expect(find.text('Status: Stopped'), findsOneWidget);
    });
  });
}
