# CarbonChain

A mobile app for tracking carbon emissions across delivery trips. Drivers log fuel type, load weight, and engine efficiency before a trip — the app uses GPS to measure distance and idle time, then calculates CO₂ output and generates AI-powered insights.

## Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Android / iOS / Web) |
| Backend | Node.js + Express + TypeScript |
| Database | Supabase (PostgreSQL) |
| AI insights | OpenRouter (GPT-4o-mini) |

## Features

- Real-time GPS distance tracking using Haversine formula
- Idle time detection (sub-5m GPS updates)
- Break/pause button — excludes driver breaks from idle time
- Engine efficiency input for accurate CO₂ calculation
- AI-generated trip insights via OpenRouter
- Demo Trip mode for showcasing without real GPS
- Dark modern UI with live animated metrics

## Project Structure

```
├── app/                  # Flutter mobile app
│   ├── lib/
│   │   ├── screens/      # HomeScreen, ResultScreen
│   │   ├── services/     # GpsTracker, TripApiService
│   │   └── utils/        # Haversine, location permission
│   └── pubspec.yaml
├── backend/              # Node.js/Express API
│   ├── src/
│   │   ├── routes/       # POST /add-trip
│   │   ├── middleware/   # Request validation
│   │   ├── emissionCalculator.ts
│   │   ├── tripStore.ts
│   │   └── aiInsights.ts
│   └── package.json
└── supabase/
    └── migrations/       # SQL migrations
```

## Emission Formula

```
carbon_kg = distance_km × emission_factor × (10 / engine_efficiency_kmpl) + idle_minutes × 0.5
```

- Diesel emission factor: 2.6 kg/km
- Petrol emission factor: 2.3 kg/km
- Idle factor: 0.5 kg/min
- Engine efficiency adjusts driving emissions relative to 10 km/L baseline

## Setup

### 1. Supabase

Create a project at [supabase.com](https://supabase.com) and run the migrations in `supabase/migrations/` via the SQL Editor.

### 2. Backend

```bash
cd backend
cp .env.example .env
# Fill in SUPABASE_URL, SUPABASE_KEY, OPENROUTER_API_KEY
npm install
npx ts-node src/index.ts
```

### 3. Flutter App

```bash
cd app
flutter pub get
flutter run -d chrome        # browser
flutter run                  # connected Android device
flutter build apk --release  # build installable APK
```

Update `app/lib/services/trip_api_service.dart` with your backend URL before building.

## Environment Variables

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_KEY` | Supabase anon key |
| `OPENROUTER_API_KEY` | OpenRouter API key for AI insights |

## Deployment

- **Backend**: Deploy to [Render](https://render.com) — set root to `backend/`, build command `npm install && npm run build`, start command `node dist/index.js`
- **App**: Build APK with `flutter build apk --release` and share directly, or publish to Google Play

## Running Tests

```bash
# Backend
cd backend && npx jest --no-coverage

# Flutter
cd app && flutter test
```
