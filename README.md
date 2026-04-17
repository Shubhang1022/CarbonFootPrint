# CarbonChain — Fleet Carbon Emissions Tracker

> Built for Google Solution Challenge 2026

---

## The Problem

India's logistics and delivery sector operates millions of trucks daily, yet most fleet operators have zero visibility into their carbon footprint. Drivers have no feedback on their driving behaviour, fleet owners can't identify which vehicles or routes are most polluting, and there's no system to detect overspeeding, excessive idling, or inefficient engine usage in real time.

The result: unchecked emissions, no accountability, and no data to drive sustainability decisions.

---

## What CarbonChain Solves

CarbonChain gives every delivery fleet — from a 5-truck local operator to a large logistics company — a complete, AI-powered carbon tracking system accessible from a single mobile app.

- Drivers track every trip automatically using GPS
- Fleet owners see real-time CO₂ data for every vehicle and driver
- AI identifies patterns, flags overspeeding, and recommends actions
- All data is stored centrally and accessible anytime

---

## How It Works

### For Drivers

1. Driver opens the app and logs in via phone OTP or email
2. Selects fuel type, load weight, and engine efficiency
3. Taps **Start Trip** — GPS begins tracking automatically
4. Live dashboard shows: current speed, distance covered, idle time, ignition time
5. Driver can take a **Break** (pauses tracking so rest time isn't counted as idle)
6. Taps **Stop Trip** — data is sent to the backend
7. Result screen shows: total CO₂ emitted, efficiency score, AI-generated insights, money savings estimate
8. All trips are saved to the driver's history

### For Fleet Owners

1. Owner logs in and creates their company
2. Drivers search for the company and send a join request
3. Owner reviews and accepts/rejects requests from the **Requests** tab
4. Once accepted, driver's trips automatically appear in the owner's dashboard
5. Owner sees:
   - Total fleet CO₂ (Day / Week / Month / Annual)
   - Per-driver CO₂ breakdown in a table with truck numbers
   - Overspeeding alerts with driver name, date, time, and max speed
   - AI fleet insights generated from real trip data
6. Owner can chat with the **AI Assistant** to ask questions about their fleet

---

## Key Features

### GPS Tracking
- Stream-based location updates (fires every 10m of movement)
- Dual-condition movement detection: speed ≥ 3 km/h AND distance ≥ 15m per update
- GPS accuracy filter: rejects fixes worse than 20m accuracy
- Prevents GPS drift from inflating distance when stationary

### Emission Calculation
- Formula: `CO₂ = distance × emission_factor × (10 / engine_efficiency) + idle_time × 0.5`
- Diesel: 2.6 kg/km, Petrol: 2.3 kg/km
- Engine efficiency adjusts emissions relative to a 10 km/L baseline
- A less efficient engine burns more fuel → higher CO₂

### Live Metrics During Trip
- Speedometer with colour-coded bar (green < 40, orange < 80, red ≥ 80 km/h)
- Max speed tracked throughout trip
- Ignition time (total trip duration)
- Idle time (time vehicle wasn't moving)
- Driver break time (manual pause, excluded from idle)
- Distance in km

### AI Features
- **Per-trip insights**: 3 actionable recommendations after every trip
- **Efficiency score**: 0–100 based on engine efficiency and idle ratio
- **Comparison to average**: how the driver compares to fleet benchmarks
- **Money savings estimate**: potential fuel cost savings in ₹
- **Real-time coaching**: AI tip every 2 minutes during active trip
- **Fleet insights**: AI analysis of all drivers' data for the owner
- **AI Assistant**: owner can chat directly with an AI that has full access to fleet data — driver names, CO₂ values, overspeeding incidents, pending requests

### Admin / Owner Dashboard
- 4 tabs: Analytics, Speed Alerts, Drivers, Requests
- Total fleet CO₂ with period selector (Day / Week / Month / Annual)
- Driver table: name, truck number, location, CO₂ for selected period
- Overspeeding log: driver, date, time, max speed, truck number
- Pending join requests with Accept / Reject
- Floating AI assistant chat panel

### Authentication
- Phone number + SMS OTP (via Twilio)
- Email + OTP (via Supabase email auth)
- Role-based routing: Driver → trip tracking, Owner → fleet dashboard
- First-time profile setup: name, DOB, location, truck number (driver), company name (owner)
- Driver sends join request to company → owner approves → driver linked to fleet
- Pending approval screen while waiting for owner response

### Language Support
- Full English / Hindi toggle in the driver app
- All UI text, buttons, labels, and AI prompts switch language

### Data & Infrastructure
- All trip data stored in Supabase (PostgreSQL)
- Backend on Render (Node.js / Express / TypeScript)
- Keep-alive pings every 12 hours to prevent Supabase free tier pause
- Self-ping every 14 minutes to prevent Render sleep

---

## Architecture

```
Driver App (Flutter)
    │
    ├── GPS Stream → distance, speed, idle time, max speed
    ├── Trip submission → Render backend
    │       ├── Emission calculation
    │       ├── AI insights (OpenRouter / GPT-4o-mini)
    │       └── Supabase insert (emissions table)
    └── Auth → Supabase Auth (phone OTP / email OTP)

Owner App (same APK, different role)
    │
    ├── Fleet stats → Supabase queries (filtered by company_id)
    ├── Fleet analytics → Render backend (/fleet-analytics)
    ├── AI assistant → Render backend (/ai-assistant)
    └── Driver requests → Supabase (driver_requests table)
```

---

## Database Schema

| Table | Key Columns |
|---|---|
| `profiles` | id, name, phone, role, company_id, truck_number, status |
| `companies` | id, name, owner_id, owner_email |
| `emissions` | id, distance, idle_time, fuel_type, carbon_kg, engine_efficiency, max_speed, user_id, company_id |
| `driver_requests` | id, driver_id, company_id, status |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter (Android) |
| Backend API | Node.js + Express + TypeScript |
| Database | Supabase (PostgreSQL) |
| Auth | Supabase Auth (Phone OTP + Email OTP) |
| AI | OpenRouter — GPT-4o-mini |
| Hosting | Render (backend) |

---

## SDG Alignment

**SDG 13 — Climate Action**: Directly reduces transport sector emissions by giving drivers and fleet operators the data and AI guidance needed to make sustainable decisions.

**SDG 9 — Industry, Innovation and Infrastructure**: Brings modern IoT-style fleet monitoring to small and medium logistics operators who previously had no access to such tools.

**SDG 11 — Sustainable Cities and Communities**: Cleaner delivery fleets mean less urban air pollution, contributing to healthier cities.
