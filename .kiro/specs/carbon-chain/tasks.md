# Implementation Plan: CarbonChain Carbon Tracking System

## Overview

Implement a Flutter mobile app with a Node.js/Express backend and Supabase database for tracking carbon emissions across delivery trips. Tasks are ordered to build the backend first (independently testable), then the Flutter app, then wire them together.

## Tasks

- [x] 1. Set up project structure and configuration
  - Initialise a Node.js/Express project under `backend/` with TypeScript
  - Initialise a Flutter project under `app/`
  - Add `dotenv` to backend; create `.env.example` with `SUPABASE_URL` and `SUPABASE_KEY`
  - Create Supabase `emissions` table migration SQL: `id UUID PK`, `distance FLOAT`, `idle_time FLOAT`, `fuel_type TEXT`, `carbon_kg FLOAT`, `created_at TIMESTAMPTZ DEFAULT now()`
  - _Requirements: 7.1, 7.5_

- [x] 2. Implement backend emission calculation
  - [x] 2.1 Implement `EmissionCalculator` module
    - Create `backend/src/emissionCalculator.ts` with function `calculateCarbon(distance, fuelType, idleTime): number`
    - Apply formula: `carbon_kg = distance * emissionFactor + idleTime * 0.5`
    - Diesel factor = 2.6, petrol factor = 2.3
    - _Requirements: 6.1, 6.2, 6.3_

  - [x] 2.2 Write property test for EmissionCalculator
    - **Property 1: Linearity — doubling distance doubles the driving component of carbon**
    - **Property 2: Idle contribution — carbon increases by 0.5 per additional idle minute regardless of fuel type**
    - **Property 3: Diesel always produces more carbon than petrol for the same inputs**
    - **Validates: Requirements 6.1, 6.2, 6.3**

  - [x] 2.3 Implement request validation middleware
    - Validate presence of `distance`, `fuel_type`, `idle_time`, `load_weight`
    - Validate `fuel_type` is "diesel" or "petrol"
    - Validate `distance` and `idle_time` are numeric
    - Return HTTP 400 with descriptive message on failure
    - _Requirements: 6.4, 6.5, 6.6_

  - [x] 2.4 Write unit tests for validation middleware
    - Test each missing-field case returns 400
    - Test invalid fuel_type returns 400
    - Test non-numeric distance/idle_time returns 400
    - _Requirements: 6.4, 6.5, 6.6_

- [x] 3. Implement backend `/add-trip` endpoint and persistence
  - [x] 3.1 Implement `TripStore` module
    - Create `backend/src/tripStore.ts` using `@supabase/supabase-js`
    - Read credentials from `process.env.SUPABASE_URL` and `process.env.SUPABASE_KEY`
    - Implement `insertTrip(record): Promise<void>` — inserts into `emissions` table with auto UUID and UTC timestamp
    - On insert failure, log error but do not throw
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 3.2 Wire `POST /add-trip` route
    - Create `backend/src/routes/addTrip.ts`
    - Apply validation middleware, call `calculateCarbon`, call `insertTrip`, return `{"carbon": <value>}` with HTTP 200
    - _Requirements: 5.1, 6.1, 6.7, 7.1_

  - [x] 3.3 Write integration tests for `/add-trip`
    - Test happy path returns `{"carbon": ...}` with correct value
    - Test DB failure still returns carbon value (mock Supabase)
    - _Requirements: 6.7, 7.4_

- [x] 4. Checkpoint — Ensure all backend tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement Flutter GPS tracking
  - [x] 5.1 Add `geolocator` package and permission handling
    - Add `geolocator` to `pubspec.yaml`
    - Configure `AndroidManifest.xml` and `Info.plist` for location permissions
    - On first launch, request location permission via `Geolocator.requestPermission()`
    - If denied, show error dialog: "GPS access is required to track trips"
    - _Requirements: 1.4, 1.5_

  - [x] 5.2 Implement `GpsTracker` service
    - Create `app/lib/services/gps_tracker.dart`
    - On `startTracking()`: begin polling at 5-second intervals using a `Timer.periodic`
    - On `stopTracking()`: cancel the timer
    - Store `previousLocation` and `currentLocation` in memory
    - On GPS unavailable, retain last known location and continue polling
    - _Requirements: 1.1, 1.2, 1.3, 1.6_

  - [x] 5.3 Write unit tests for GpsTracker
    - Test that stopTracking cancels polling
    - Test that last known location is retained when signal is unavailable
    - _Requirements: 1.2, 1.6_

- [x] 6. Implement distance and idle time calculation
  - [x] 6.1 Implement Haversine distance function
    - Create `app/lib/utils/haversine.dart` with `double haversine(LatLng a, LatLng b)`
    - _Requirements: 2.1_

  - [x] 6.2 Write property test for Haversine
    - **Property 4: haversine(a, a) == 0 for any point**
    - **Property 5: haversine(a, b) == haversine(b, a) (symmetry)**
    - **Property 6: triangle inequality holds for any three points**
    - **Validates: Requirements 2.1**

  - [x] 6.3 Implement distance accumulation logic in `GpsTracker`
    - On each GPS update, compute incremental distance via `haversine`
    - If incremental distance < 5 m, discard and increment idle counter by 5 s
    - If incremental distance >= 5 m, add to cumulative distance; do not increment idle counter
    - Reset both counters on `startTracking()`
    - _Requirements: 2.2, 2.3, 2.5, 3.1, 3.2, 3.4_

  - [x] 6.4 Write unit tests for distance accumulation
    - Test sub-5m update is discarded from distance but adds to idle
    - Test >= 5m update is added to distance and does not add to idle
    - Test reset on start
    - _Requirements: 2.2, 2.3, 2.5, 3.1, 3.2, 3.4_

- [x] 7. Implement Flutter Home Screen UI
  - [x] 7.1 Create `HomeScreen` widget
    - Create `app/lib/screens/home_screen.dart`
    - Fuel type dropdown ("diesel" / "petrol")
    - Numeric load weight input field
    - Trip status label ("Stopped" / "Running")
    - Current distance display (km, updated per accepted GPS reading)
    - Current idle time display (whole minutes)
    - "Start Trip" and "Stop Trip" buttons
    - _Requirements: 4.1, 4.2, 9.1, 9.2, 2.4, 3.3_

  - [x] 7.2 Implement input validation and button state logic
    - On "Start Trip": validate fuel type selected and load weight non-empty; show validation errors if not
    - While trip active: disable fuel type and load weight inputs; disable "Start Trip"; enable "Stop Trip"
    - While trip inactive: enable inputs; enable "Start Trip"; disable "Stop Trip"
    - _Requirements: 4.3, 4.4, 4.5, 9.3, 9.4_

  - [x] 7.3 Write widget tests for HomeScreen
    - Test validation errors shown when fields empty on start
    - Test input fields disabled while trip active
    - Test button states match trip status
    - _Requirements: 4.3, 4.4, 4.5, 9.3, 9.4_

- [x] 8. Implement trip submission and Result Screen
  - [x] 8.1 Implement `TripApiService`
    - Create `app/lib/services/trip_api_service.dart`
    - `submitTrip({distance, fuelType, idleTime, loadWeight})` sends POST to `/add-trip`
    - 15-second timeout; on timeout throw `TimeoutException`
    - _Requirements: 5.1, 5.5_

  - [x] 8.2 Wire "Stop Trip" submission flow in `HomeScreen`
    - On "Stop Trip": show loading indicator, disable button, call `TripApiService.submitTrip`
    - On success: navigate to `ResultScreen` with returned carbon value, distance, idle time
    - On error response: show error message, remain on Home Screen
    - On timeout: show timeout error, allow retry
    - _Requirements: 5.2, 5.3, 5.4, 5.5_

  - [x] 8.3 Create `ResultScreen` widget
    - Create `app/lib/screens/result_screen.dart`
    - Display total distance (km), idle time (minutes), carbon emissions (kg CO₂)
    - "New Trip" button navigates back to Home Screen and resets all trip state
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x] 8.4 Write widget tests for ResultScreen and submission flow
    - Test all three values displayed correctly
    - Test "New Trip" resets state
    - Test loading indicator shown during submission
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 5.2_

- [x] 9. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties (linearity, symmetry, monotonicity)
- Unit/widget tests validate specific examples and edge cases
