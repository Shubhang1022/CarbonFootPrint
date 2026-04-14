# Requirements Document

## Introduction

CarbonChain is a mobile application for tracking carbon emissions in supply chain delivery trips. The system consists of a Flutter mobile app that uses GPS to track trips in real time, and a Node.js backend that calculates carbon emissions based on distance, fuel type, idle time, and load weight. Trip results are persisted in a Supabase database. The goal is to give delivery operators a simple, accurate view of their carbon footprint per trip.

## Glossary

- **App**: The Flutter mobile application running on the driver's device
- **Backend**: The Node.js + Express server that handles emission calculations
- **Database**: The Supabase PostgreSQL instance storing trip records
- **Trip**: A single delivery journey from start to stop
- **GPS_Tracker**: The App subsystem responsible for polling device location
- **Emission_Calculator**: The Backend subsystem that computes carbon output
- **Trip_Store**: The Database subsystem that persists trip records
- **Idle_Detector**: The App subsystem that identifies periods of no movement
- **Emission_Factor**: A per-km CO₂ coefficient specific to a fuel type (diesel = 2.6 kg/km, petrol = 2.3 kg/km)
- **Idle_Factor**: A per-minute CO₂ coefficient for idling (0.5 kg/min)
- **Load_Weight**: The cargo weight in kilograms for the trip

---

## Requirements

### Requirement 1: GPS Trip Tracking

**User Story:** As a delivery driver, I want the app to track my GPS location during a trip, so that distance is calculated automatically without manual input.

#### Acceptance Criteria

1. WHEN the driver presses "Start Trip", THE GPS_Tracker SHALL begin polling the device location at 5-second intervals.
2. WHEN the driver presses "Stop Trip", THE GPS_Tracker SHALL cease all location polling.
3. WHILE a trip is active, THE GPS_Tracker SHALL store the most recent and previous location coordinates in memory.
4. WHEN the App is launched for the first time, THE App SHALL request device location permission from the operating system.
5. IF location permission is denied, THEN THE App SHALL display an error message informing the driver that GPS access is required to track trips.
6. IF the GPS signal is unavailable during an active trip, THEN THE GPS_Tracker SHALL retain the last known location and continue polling until a signal is restored.

---

### Requirement 2: Incremental Distance Calculation

**User Story:** As a delivery driver, I want the app to calculate trip distance incrementally from GPS data, so that I can see my current distance in real time.

#### Acceptance Criteria

1. WHEN a new GPS location is received, THE GPS_Tracker SHALL compute the distance between the previous and current coordinates using the Haversine formula.
2. WHEN the computed incremental distance is less than 5 meters, THE GPS_Tracker SHALL discard the update and not add it to the total distance.
3. WHEN the computed incremental distance is 5 meters or greater, THE GPS_Tracker SHALL add the incremental distance to the cumulative trip distance.
4. WHILE a trip is active, THE App SHALL display the current cumulative distance in kilometers, updated after each accepted GPS reading.
5. WHEN "Start Trip" is pressed, THE GPS_Tracker SHALL reset the cumulative distance to zero.

---

### Requirement 3: Idle Time Detection

**User Story:** As a fleet manager, I want idle time to be tracked automatically, so that idle emissions are included in the carbon calculation.

#### Acceptance Criteria

1. WHEN a GPS update is received and the incremental distance is less than 5 meters, THE Idle_Detector SHALL increment the idle counter by 5 seconds.
2. WHEN a GPS update is received and the incremental distance is 5 meters or greater, THE Idle_Detector SHALL not increment the idle counter.
3. WHILE a trip is active, THE App SHALL display the current idle time in whole minutes.
4. WHEN "Start Trip" is pressed, THE Idle_Detector SHALL reset the idle counter to zero.

---

### Requirement 4: Trip Input Fields

**User Story:** As a delivery driver, I want to specify fuel type and load weight before starting a trip, so that the carbon calculation reflects my vehicle's actual configuration.

#### Acceptance Criteria

1. THE App SHALL provide a dropdown input allowing the driver to select a fuel type of either "diesel" or "petrol".
2. THE App SHALL provide a numeric input field for the driver to enter the load weight in kilograms.
3. WHEN "Start Trip" is pressed and no fuel type is selected, THE App SHALL display a validation error and not begin tracking.
4. WHEN "Start Trip" is pressed and the load weight field is empty, THE App SHALL display a validation error and not begin tracking.
5. WHILE a trip is active, THE App SHALL disable the fuel type and load weight input fields.

---

### Requirement 5: Trip Submission to Backend

**User Story:** As a delivery driver, I want the app to send trip data to the backend when I stop a trip, so that carbon emissions are calculated and stored.

#### Acceptance Criteria

1. WHEN "Stop Trip" is pressed, THE App SHALL send a POST request to the Backend at the `/add-trip` endpoint with the fields: `distance`, `fuel_type`, `idle_time`, and `load_weight`.
2. WHILE the POST request is in flight, THE App SHALL display a loading indicator and disable the "Stop Trip" button.
3. WHEN the Backend returns a successful response, THE App SHALL navigate to the Result Screen displaying the returned carbon value.
4. IF the Backend returns an error response, THEN THE App SHALL display an error message and remain on the Home Screen.
5. IF the network request times out after 15 seconds, THEN THE App SHALL display a timeout error message and allow the driver to retry.

---

### Requirement 6: Carbon Emission Calculation

**User Story:** As a fleet manager, I want carbon emissions to be calculated using a standard formula, so that results are consistent and auditable.

#### Acceptance Criteria

1. WHEN the Backend receives a POST `/add-trip` request, THE Emission_Calculator SHALL compute carbon emissions using the formula: `carbon_kg = distance * emission_factor + idle_time * 0.5`.
2. WHEN the fuel type in the request is "diesel", THE Emission_Calculator SHALL use an emission factor of 2.6 kg/km.
3. WHEN the fuel type in the request is "petrol", THE Emission_Calculator SHALL use an emission factor of 2.3 kg/km.
4. IF the request body is missing any of the required fields (`distance`, `fuel_type`, `idle_time`, `load_weight`), THEN THE Backend SHALL return an HTTP 400 response with a descriptive error message.
5. IF the `fuel_type` value is not "diesel" or "petrol", THEN THE Backend SHALL return an HTTP 400 response with a descriptive error message.
6. IF `distance` or `idle_time` contain non-numeric values, THEN THE Backend SHALL return an HTTP 400 response with a descriptive error message.
7. WHEN the calculation is complete, THE Backend SHALL return an HTTP 200 response with the JSON body `{"carbon": <value>}`.

---

### Requirement 7: Trip Persistence

**User Story:** As a fleet manager, I want every trip result to be stored in the database, so that historical emissions data is available for reporting.

#### Acceptance Criteria

1. WHEN the Emission_Calculator completes a carbon calculation, THE Trip_Store SHALL insert a record into the `emissions` table with fields: `id` (UUID), `distance`, `idle_time`, `fuel_type`, `carbon_kg`, and `created_at`.
2. THE Trip_Store SHALL generate a UUID for the `id` field automatically.
3. THE Trip_Store SHALL set `created_at` to the UTC timestamp at the time of insertion.
4. IF the database insert fails, THEN THE Backend SHALL log the error and still return the calculated carbon value to the App.
5. THE Backend SHALL read Supabase connection credentials exclusively from environment variables and not from hardcoded values.

---

### Requirement 8: Result Screen

**User Story:** As a delivery driver, I want to see a summary of my trip after stopping, so that I know the total distance, idle time, and carbon emissions.

#### Acceptance Criteria

1. WHEN the App navigates to the Result Screen, THE App SHALL display the total trip distance in kilometers.
2. WHEN the App navigates to the Result Screen, THE App SHALL display the total idle time in minutes.
3. WHEN the App navigates to the Result Screen, THE App SHALL display the carbon emission value received from the Backend in kg CO₂.
4. THE Result Screen SHALL provide a button that navigates the driver back to the Home Screen to start a new trip.
5. WHEN the driver navigates back to the Home Screen from the Result Screen, THE App SHALL reset all trip state (distance, idle time, trip status) to initial values.

---

### Requirement 9: Trip Status Display

**User Story:** As a delivery driver, I want to see the current trip status on the Home Screen, so that I know whether tracking is active.

#### Acceptance Criteria

1. WHILE no trip is active, THE App SHALL display the trip status as "Stopped".
2. WHILE a trip is active, THE App SHALL display the trip status as "Running".
3. WHILE a trip is active, THE App SHALL disable the "Start Trip" button.
4. WHILE no trip is active, THE App SHALL disable the "Stop Trip" button.
