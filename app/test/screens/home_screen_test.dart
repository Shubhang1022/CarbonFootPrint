import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:carbon_chain/screens/home_screen.dart';
import 'package:carbon_chain/services/gps_tracker.dart';

/// A [GpsTracker] that never actually polls GPS — safe for widget tests.
class _FakeGpsTracker extends GpsTracker {
  bool trackingStarted = false;
  bool trackingStopped = false;

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
    trackingStarted = true;
    // Do NOT call super — avoids real Timer / Geolocator calls.
    cumulativeDistanceM = 0.0;
    idleTimeSeconds = 0;
  }

  @override
  void stopTracking() {
    trackingStopped = true;
  }
}

/// Builds a [HomeScreen] with injected fakes so no platform channels fire.
Widget _buildHomeScreen({
  _FakeGpsTracker? tracker,
  Future<bool> Function(BuildContext)? permissionChecker,
}) {
  return MaterialApp(
    home: HomeScreen(
      tracker: tracker ?? _FakeGpsTracker(),
      permissionChecker: permissionChecker ?? (_) async => true,
    ),
  );
}

void main() {
  group('HomeScreen — initial state (Req 9.1, 9.3, 9.4)', () {
    testWidgets('status shows Stopped on launch', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());

      expect(find.text('Status: Stopped'), findsOneWidget);
    });

    testWidgets('Start Trip button is enabled on launch (Req 9.3)', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());

      final startBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Start Trip'),
      );
      expect(startBtn.onPressed, isNotNull);
    });

    testWidgets('Stop Trip button is disabled on launch (Req 9.4)', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());

      final stopBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Stop Trip'),
      );
      expect(stopBtn.onPressed, isNull);
    });
  });

  group('HomeScreen — validation (Req 4.3, 4.4)', () {
    testWidgets('shows fuel type error when Start Trip tapped with no fuel type (Req 4.3)',
        (tester) async {
      await tester.pumpWidget(_buildHomeScreen());

      // Enter a load weight but leave fuel type unselected.
      await tester.enterText(find.byType(TextFormField), '500');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Trip'));
      await tester.pump();

      expect(find.text('Please select a fuel type'), findsOneWidget);
    });

    testWidgets('shows load weight error when Start Trip tapped with empty weight (Req 4.4)',
        (tester) async {
      await tester.pumpWidget(_buildHomeScreen());

      // Select a fuel type but leave load weight empty.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diesel').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Trip'));
      await tester.pump();

      expect(find.text('Please enter load weight'), findsOneWidget);
    });

    testWidgets('shows both errors when Start Trip tapped with no inputs', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Trip'));
      await tester.pump();

      expect(find.text('Please select a fuel type'), findsOneWidget);
      expect(find.text('Please enter load weight'), findsOneWidget);
    });
  });

  group('HomeScreen — active trip state (Req 4.5, 9.2, 9.3)', () {
    Future<void> startTrip(WidgetTester tester) async {
      // Select diesel.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diesel').last);
      await tester.pumpAndSettle();

      // Enter load weight.
      await tester.enterText(find.byType(TextFormField), '500');

      // Tap Start Trip.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Trip'));
      await tester.pumpAndSettle();
    }

    testWidgets('status shows Running after starting trip (Req 9.2)', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());
      await startTrip(tester);

      expect(find.text('Status: Running'), findsOneWidget);
    });

    testWidgets('Start Trip button disabled while trip active (Req 9.3)', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());
      await startTrip(tester);

      final startBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Start Trip'),
      );
      expect(startBtn.onPressed, isNull);
    });

    testWidgets('Stop Trip button enabled while trip active (Req 9.4)', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());
      await startTrip(tester);

      final stopBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Stop Trip'),
      );
      expect(stopBtn.onPressed, isNotNull);
    });

    testWidgets('fuel type dropdown disabled while trip active (Req 4.5)', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());
      await startTrip(tester);

      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.onChanged, isNull);
    });

    testWidgets('load weight field disabled while trip active (Req 4.5)', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());
      await startTrip(tester);

      final textField = tester.widget<TextFormField>(
        find.byType(TextFormField),
      );
      expect(textField.enabled, isFalse);
    });
  });

  group('HomeScreen — stopped trip state (Req 9.1, 9.3, 9.4)', () {
    Future<void> startThenStopTrip(WidgetTester tester) async {
      // Select petrol.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Petrol').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '300');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Trip'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop Trip'));
      await tester.pumpAndSettle();
    }

    testWidgets('status shows Stopped after stopping trip (Req 9.1)', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());
      await startThenStopTrip(tester);

      expect(find.text('Status: Stopped'), findsOneWidget);
    });

    testWidgets('Start Trip button re-enabled after stopping trip (Req 9.3)', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());
      await startThenStopTrip(tester);

      final startBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Start Trip'),
      );
      expect(startBtn.onPressed, isNotNull);
    });

    testWidgets('Stop Trip button disabled after stopping trip (Req 9.4)', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());
      await startThenStopTrip(tester);

      final stopBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Stop Trip'),
      );
      expect(stopBtn.onPressed, isNull);
    });

    testWidgets('inputs re-enabled after stopping trip (Req 4.5)', (tester) async {
      await tester.pumpWidget(_buildHomeScreen());
      await startThenStopTrip(tester);

      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.onChanged, isNotNull);

      final textField = tester.widget<TextFormField>(
        find.byType(TextFormField),
      );
      expect(textField.enabled, isTrue);
    });
  });
}
