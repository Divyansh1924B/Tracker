# Family Tracker

A private family location tracking application with offline synchronization, 1-year route history, and real-time administrative dashboards.

## Project Structure

```
Tracker/
├── backend/            # Node.js + TypeScript + PostgreSQL
└── frontend/           # Flutter (Riverpod + go_router + SQLite)
```

## Tech Stack

### Frontend
- **Framework**: Flutter (Latest Stable)
- **State Management**: Riverpod (with Generator)
- **Routing**: `go_router`
- **Mapping**: `flutter_map` + OpenStreetMap (MapLibre compatible)
- **Local DB**: `sqflite` (SQLite)
- **Network**: `dio`

### Backend
- **Runtime**: Node.js + TypeScript
- **Framework**: Express.js
- **Database**: PostgreSQL (Neon / Supabase)
- **Auth**: JWT & bcrypt
- **Realtime**: WebSockets (`ws`)

## Setup Instructions

### Backend
1. Navigate to `/backend`
2. Run `npm install`
3. Configure your `.env` variables
4. Run `npm run dev`

### Frontend
1. Navigate to `/frontend`
2. Run `flutter pub get`
3. Run `flutter run`
