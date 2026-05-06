# DINE OPS — Production-Grade Restaurant Management System

## Stack
- **Frontend**: Flutter + Riverpod + Clean Architecture
- **Backend**: NestJS + MongoDB Atlas + Socket.io
- **Offline**: Hive + SyncEngine
- **Push**: Firebase Cloud Messaging

---

## Project Structure

```
RMS/
├── flutter_app/          # Flutter frontend
│   └── lib/
│       ├── core/         # Config, network, services, errors
│       ├── data/         # Models, repositories, datasources
│       ├── domain/       # Entities, repository contracts, use cases
│       └── presentation/ # Screens, widgets, Riverpod state
│
└── backend/              # NestJS backend
    └── src/
        ├── modules/      # orders, auth, users, tables, menu, billing, inventory
        ├── gateways/     # WebSocket (Socket.io)
        └── common/       # Guards, decorators, filters, interceptors
```

---

## Quick Start

### Backend
```bash
cd backend
cp .env.example .env        # fill in MONGODB_URI + JWT_SECRET
npm install
npm run start:dev
```

### Flutter
```bash
cd flutter_app
flutter pub get
flutter run
```

---

## API Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| POST | /auth/login | * | Login, returns JWT |
| GET | /orders/active | all staff | Live active orders |
| GET | /orders/:id | all staff | Single order |
| POST | /orders | waiter/manager | Create order |
| PATCH | /orders/:id/status | all staff | Advance order state |
| PATCH | /orders/:id/items/:itemId/progress | chef | Update cooking progress |

All mutating endpoints require `Idempotency-Key` header.

---

## Engineering Constraints Implemented

| Problem | Solution |
|---------|----------|
| Concurrent edits | Optimistic locking via `version` field + 409 on mismatch |
| Duplicate requests | `Idempotency-Key` stored in `processedKeys[]` per document |
| Offline mutations | SyncEngine queues to Hive, replays on reconnect |
| Network drop | Retry interceptor with exponential backoff (3 attempts) |
| Real-time miss | WebSocket + polling fallback every 8s + ACK retry system |
| State conflicts | Server authority — client rolls back optimistic update on 409 |
| Invalid transitions | State machine enforced on both client and server |

---

## WebSocket Events

| Event | Direction | Payload |
|-------|-----------|---------|
| `order:created` | server → client | OrderDocument |
| `order:updated` | server → client | OrderDocument |
| `kitchen:progress` | server → client | `{ orderId, itemId, progress }` |
| `ack` | client → server | `{ eventId }` |

---

## Order State Machine

```
CREATED → CONFIRMED → PREPARING → READY → SERVED → BILLED → PAID → CLOSED
```
Invalid transitions are rejected with 400 on the server and blocked in the Flutter state machine.
