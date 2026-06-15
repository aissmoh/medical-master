# Medical Master — Project State

> Last updated: 2026-06-15 22:40 (Morocco time)
> Backup: ~/Desktop/MedicalMaster_2026-06-15_20-22/

---

## 1. PROJECT OVERVIEW

Real-time medical patient monitoring system with 3 parts:
1. **Backend API** — Node.js/Express + MongoDB + Socket.io (port 5000)
2. **Web Admin Dashboard** — SPA vanilla JS served by Nginx (port 80)
3. **Flutter Mobile App** — Patient & nurse interfaces

```
ESP32 --POST /vitals/arduino--> Backend --> MongoDB
                                    |
Flutter App --API + Socket.io--> Backend
Dashboard   --API + Socket.io--> Backend (via Nginx proxy)
                                    |
                              Cloudflare Tunnel --> birapp.dpdns.org
```

---

## 2. ACCESS POINTS

| URL | What |
|-----|------|
| https://birapp.dpdns.org | Public (Cloudflare) |
| http://localhost:8081 | Host to Docker |
| http://localhost:5000 | Backend directly (inside container) |

### Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@medical-master.com | admin123 |
| Nurse | marie@test.com | nurse123 |
| Patient | sync@test.com | sync123 |

---

## 3. DOCKER

- Container: `studentesp32`
- Image: `maissaoui/mywebserver:v2`
- OS: Ubuntu 24.04 x86_64
- Ports: `8081:80`
- Connect: `docker exec -it studentesp32 bash`
- **No Flutter SDK/Android SDK/JDK** — APK builds on host only

---

## 4. SERVICES

```bash
docker exec studentesp32 bash -c '/var/www/start.sh restart'
docker exec studentesp32 bash -c '/var/www/start.sh start'
docker exec studentesp32 bash -c '/var/www/start.sh stop'
docker exec studentesp32 bash -c '/var/www/start.sh status'
```

| Service | Port | Manager |
|---------|------|---------|
| MongoDB | 27017 | system |
| Nginx | 80 | system |
| medical-master | 5000 | PM2 cluster |
| cloudflare-tunnel | -- | PM2 fork |

PM2 commands:
```bash
docker exec studentesp32 pm2 list
docker exec studentesp32 pm2 logs medical-master
docker exec studentesp32 pm2 restart medical-master
docker exec studentesp32 pm2 save
```

---

## 5. FILE STRUCTURE

```
/var/www/
├── esp32/
│   └── esp32_code.ino
├── flutter-app/
│   ├── lib/
│   │   ├── main.dart / app.dart
│   │   ├── services/
│   │   ├── models/
│   │   ├── views/
│   │   ├── controllers/
│   │   └── providers/
│   ├── android/ ios/ web/
│   ├── assets/
│   └── pubspec.yaml
├── webserver/
│   ├── server.js
│   ├── package.json
│   ├── .env
│   ├── ecosystem.config.cjs
│   ├── socket.js
│   ├── config/
│   ├── controllers/ (11 files)
│   ├── models/ (11 files)
│   ├── routes/ (11 files)
│   ├── middleware/
│   ├── services/
│   ├── scripts/
│   ├── index.html
│   ├── js/app.js
│   ├── css/style.css
│   ├── simulate-esp32.js
│   ├── node_modules/
│   └── logs/
├── start.sh
├── start.sh.bak
├── startup.log
└── state.md
```

---

## 6. CONFIG FILES

### .env

```
MONGO_URI=mongodb://localhost:27017/medical-master
JWT_SECRET=medical_master_jwt_secret_key_2026
ARDUINO_API_KEY=ESP32_Surveillance_2026
PORT=5000
HOST=0.0.0.0
NODE_ENV=production
```

### ecosystem.config.cjs

```javascript
module.exports = { apps: [
  { name: "medical-master", script: "/var/www/webserver/server.js",
    env: { NODE_ENV: "production", PORT: 5000 },
    max_memory_restart: "500M", instances: 1 },
  { name: "cloudflare-tunnel",
    script: "/usr/local/sbin/cloudflared",
    args: "tunnel --config /root/.cloudflared/config.yml run bir" }
]};
```

### Nginx (/etc/nginx/sites-available/medical)

```nginx
server {
    listen 80; server_name _;
    root /var/www/webserver; index index.html;
    gzip on; gzip_types text/css application/javascript application/json;

    location ~* \.(js|css)$ {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        try_files $uri =404;
    }
    location /api/ { proxy_pass http://127.0.0.1:5000; ... }
    location /socket.io/ { proxy_pass http://127.0.0.1:5000;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade"; ... }
    location / {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        try_files $uri $uri/ /index.html;
    }
}
```

### Cloudflare Tunnel (/root/.cloudflared/config.yml)

```yaml
tunnel: 66df911a-e3b4-4918-97a7-d2995362bd16
credentials-file: /root/.cloudflared/66df911a-e3b4-4918-97a7-d2995362bd16.json
ingress:
  - hostname: birapp.dpdns.org
    service: http://localhost:80
  - service: http_status:404
```

---

## 7. DATABASE

- URI: mongodb://localhost:27017/medical-master
- Data path: /data/db

| Collection | Count | Notes |
|------------|-------|-------|
| users | 4 | 1 admin, 1 nurse, 2 patients |
| vitalsigns | 16 | Vitals grouped by patient |
| heartrates | 16 | Individual heart rate readings |
| oxygenlevels | 16 | Individual SpO2 readings |
| temperatures | 16 | Individual temperature readings |
| sosalerts | 2 | SOS alerts from patients |
| emergencies | 0 | Full emergency workflow (separate from sosalerts) |
| appointments | 0 | |
| messages | 0 | |
| tasks | 0 | |
| carerequests | 0 | |

### User Schema

name, email, password (bcrypt), phone, role, isPatient (bool),
isVerified, assignedNurse (ObjectId), groupeSanguin,
dateNaissance, address, photoProfil,
language (ar|fr|en), location: {lat, lng, lastUpdated},
roomInfo: {chamber, bed}

### SOSAlert Schema (collection: sosalerts)

patientId, message, type, status (active|acknowledged|resolved|cancelled),
location: {type:"Point", coordinates:[lat,lng]},
acknowledgedBy, resolvedBy, timestamps

### Emergency Schema (collection: emergencies)

patientId, location: {lat, lng, address}, type, description,
status (pending|accepted|in_progress|resolved|cancelled),
vitalSigns, assignedNurseId, assignments[], responseTime,
nurseNotes, resolvedAt, notificationsSent[]

---

## 8. API ENDPOINTS

### Auth

| Method | Endpoint | Body |
|--------|----------|------|
| POST | /api/v1/auth/signup | name, email, phone, password, confirmPassword, isPatient, groupeSanguin |
| POST | /api/v1/auth/verify-signup-otp | email, otp |
| POST | /api/v1/auth/login | email, password -> {token, user} |
| POST | /api/v1/auth/logout | |

### Users (admin)

| Method | Endpoint | Notes |
|--------|----------|-------|
| GET | /api/v1/users?role=patient | List patients |
| GET | /api/v1/users?role=nurse | List nurses |
| GET | /api/v1/users | All users |
| GET | /api/v1/users/:id | User by ID |
| DELETE | /api/v1/users/:id | Delete user |

### Vitals

| Method | Endpoint | Auth | Notes |
|--------|----------|------|-------|
| POST | /api/v1/vitals/arduino | API key | ESP32 endpoint, no JWT |
| POST | /api/v1/vitals/record | JWT | Patient records vitals |
| GET | /api/v1/vitals/all-patients | JWT | Dashboard: latest per patient |
| GET | /api/v1/vitals/patient/:id | JWT | Single patient vitals |
| GET | /api/v1/vitals/me/latest | JWT | Own latest vitals |
| GET | /api/v1/vitals/me/history | JWT | Own history |

### Patient (Flutter)

| Method | Endpoint | Notes |
|--------|----------|-------|
| POST | /api/v1/patient/sos | Create SOS alert |
| GET | /api/v1/patient/alerts | Patient's alerts |
| PUT | /api/v1/patient/alerts/:id/cancel | Cancel alert |
| GET | /api/v1/patient/my-nurse | Assigned nurse |
| POST | /api/v1/patient/request-nurse | Request nurse |
| GET | /api/v1/patient/my-requests | Care requests |
| POST | /api/v1/patient/alert-my-nurse | Alert with GPS |
| PUT | /api/v1/patient/location | Update GPS {lat,lng} |
| GET | /api/v1/patient/users/nurses | Available nurses |

### Nurse

| Method | Endpoint | Notes |
|--------|----------|-------|
| GET | /api/v1/nurse/my-patients | Assigned patients |
| GET | /api/v1/nurse/patient/:id/details | Patient details |
| GET | /api/v1/nurse/patient/:id/vitals/chart | Patient chart data |
| GET | /api/v1/nurse/pending-requests | Pending requests |
| PATCH | /api/v1/nurse/respond-request/:id | Accept/refuse |
| GET | /api/v1/nurse/alerts | Active SOS alerts |
| GET | /api/v1/nurse/alerts/history | Alert history |
| POST | /api/v1/nurse/sos | Nurse creates SOS |
| PUT | /api/v1/nurse/alerts/:id/acknowledge | Acknowledge |
| PUT | /api/v1/nurse/alerts/:id/resolve | Resolve |

### Emergency

| Method | Endpoint | Notes |
|--------|----------|-------|
| POST | /api/v1/emergency/trigger | Trigger emergency |
| GET | /api/v1/emergency/active | Active emergencies (FIXED: queries both sosalerts AND emergencies) |
| GET | /api/v1/emergency/patient | Patient's emergencies |
| PATCH | /api/v1/emergency/:id/accept | Nurse accepts |
| PATCH | /api/v1/emergency/:id/in-progress | Mark in progress |
| PATCH | /api/v1/emergency/:id/resolve | Resolve |
| PATCH | /api/v1/emergency/:id/cancel | Cancel |
| DELETE | /api/v1/emergency/:id | Delete (admin, from both sosalerts + emergencies) |

### Appointments

| Method | Endpoint | Notes |
|--------|----------|-------|
| GET | /api/v1/appointments/all | Admin: all |
| POST | /api/v1/appointments | Create |
| PUT | /api/v1/appointments/:id | Update |
| DELETE | /api/v1/appointments/:id | Delete |

### Messages

| Method | Endpoint | Notes |
|--------|----------|-------|
| POST | /api/v1/messages | Send message |
| GET | /api/v1/messages/conversations | List conversations |
| GET | /api/v1/messages/conversation/:contactId | Get messages |
| GET | /api/v1/messages/received | Received messages |
| GET | /api/v1/messages/sent | Sent messages |
| GET | /api/v1/messages/unread/count | Unread count |
| PATCH | /api/v1/messages/:id/read | Mark read |
| PATCH | /api/v1/messages/read-all | Mark all read |
| DELETE | /api/v1/messages/:id | Delete |

### Tasks

| Method | Endpoint | Notes |
|--------|----------|-------|
| GET | /api/v1/tasks | List tasks |
| POST | /api/v1/tasks | Create task |
| PUT | /api/v1/tasks/:id | Update task |
| DELETE | /api/v1/tasks/:id | Delete task |

---

## 9. SOCKET.IO

### Auth
- Client connects with socket.auth = { token: jwt }
- Server verifies JWT, loads user, joins rooms automatically

### Rooms

| Room | Members |
|------|---------|
| user:{id} | Any logged-in user |
| patient:{id} | Patient + assigned nurse |
| nurse:{id} | Nurse |
| vitals:all | Dashboard (manual join via subscribe:all) |

### Client Events

| Event | Action |
|-------|--------|
| subscribe:all | Join vitals:all room |
| unsubscribe:all | Leave vitals:all room |
| subscribe:patient | Join patient room |
| unsubscribe:patient | Leave patient room |

### Server Events (broadcast by backend)

| Event | Emitted By | Data |
|-------|-----------|------|
| vitals:update | vitalSignsController | Patient vitals object |
| emergency:new | emergencyController | Emergency object |
| emergency:resolved | emergencyController | Resolved emergency |
| sos:new | patientController | SOS alert object |
| appointment:new | appointmentController | Appointment object |
| appointment:updated | appointmentController | Updated appointment |
| new_message | messageController | Message object |
| message_sent | messageController | Sent message |

### Dashboard Socket.io Setup (in app.js)

```javascript
var rtSocket = io(window.location.origin, { auth: { token: state.token } });
rtSocket.on('vitals:update', function(data) { loadVitals(); });
rtSocket.on('emergency:new', function(data) { loadEmergencies(); });
rtSocket.on('sos:new', function(data) { loadEmergencies(); });
rtSocket.on('new_message', function(data) { console.log('New message'); });
rtSocket.emit('subscribe:all');
```

---

## 10. WEB DASHBOARD (SPA)

- Entry: index.html -> loads js/app.js + css/style.css
- No framework, vanilla JS
- State: global state object
- Router: show(page) -> render() -> sets innerHTML
- Auth: JWT in localStorage

### Pages

| Key | Function |
|-----|----------|
| dashboard | dashboardView() |
| patients | patientsView() |
| nurses | nursesView() |
| vitals | vitalsView() |
| appointments | appointmentsView() |
| emergencies | emergenciesView() |
| messages | messagesView() |
| settings | settingsView() |
| profile | profileView() |

### Key Functions

| Function | Purpose |
|----------|---------|
| render() | Main renderer |
| renderShell(page) | Sidebar + header + pageContent |
| show(page) | Set page + render |
| handleLogin() | Login -> loadData -> show dashboard |
| loadData() | Fetch all data from API |
| api(path, opts) | Fetch wrapper with JWT |
| initRealtimeSocket() | Socket.io client |

### API Calls in Dashboard

```
loadPatients()     -> GET /users?role=patient
loadNurses()       -> GET /users?role=nurse
loadVitals()       -> GET /vitals/all-patients
loadAppointments() -> GET /appointments/all
loadEmergencies()  -> GET /emergency/active
deleteEmergency()  -> DELETE /emergency/:id
handleLogin()      -> POST /auth/login
```

### Cache Busting

When modifying app.js or style.css, update cache buster in index.html:
```html
<script src="js/app.js?v=NEWVERSION"></script>
<link rel="stylesheet" href="css/style.css?v=NEWVERSION">
```
Nginx already sends Cache-Control: no-cache for JS/CSS.

---

## 11. FLUTTER APP

Source: /var/www/flutter-app/

### Build APK (on HOST machine)

```bash
docker cp studentesp32:/var/www/flutter-app/ ~/Desktop/flutter-app/
cd ~/Desktop/flutter-app
flutter pub get
flutter build apk --release
```

### API Base URL

```
https://birapp.dpdns.org/api/v1
```

### Key Services

| Service | Purpose |
|---------|---------|
| auth_service.dart | Login, signup, logout |
| patient_service.dart | SOS, alerts, nurse, location |
| appointment_service.dart | Appointments CRUD |
| emergency_service.dart | Emergency management |
| message_service.dart | Chat messages |
| tracking_service.dart | Location tracking |
| task_service.dart | Tasks |

---

## 12. ESP32

- Code: /var/www/esp32/esp32_code.ino
- Endpoint: POST /api/v1/vitals/arduino
- Header: X-API-Key: ESP32_Surveillance_2026
- Patient ID: 6a2eb91a95f5963c254b2fff
- Sends: heartRate, oxygenLevel, temperature
- Simulator: node /var/www/webserver/simulate-esp32.js

---

## 13. ALL FIXES APPLIED (27 total)

### Real-time Sync Fixes (12)

1. Socket.io rooms for targeted delivery
2. Broadcast on vital sign creation
3. Broadcast on emergency creation/resolution
4. Broadcast on appointment CRUD
5. Broadcast on message creation
6. Dashboard joins vitals:all room
7. Patient/nurse auto-join their rooms
8. Socket reconnection handling
9. Fallback polling for vitals (10s) and emergencies (15s)
10. Online status tracking per user
11. Notification events for new alerts
12. Error handling on socket disconnect

### Dashboard Bug Fixes (6)

1. loadVitals() — flattened grouped response
2. dashboardView() — patient name lookup
3. patientVitalsView() — variable fix
4. loadEmergencies() — response key fix
5. Backend getAllAppointments route — added
6. loadAppointments() — fixed endpoint path

### Infrastructure Fixes (6)

1. Flattened project structure (backend/ -> webserver/)
2. Cloudflare cache fix — Cache-Control: no-cache headers
3. PM2 ecosystem — cloudflare-tunnel added
4. Nginx redirect loop fix
5. Socket.io CDN loaded from CDN
6. Nurse password reset (now nurse123)

### Critical Sync Fix (1)

**emergencyController.js getActiveEmergencies** — was only querying `emergencies` collection (empty), but patient SOS alerts are stored in `sosalerts` collection. Fixed to query BOTH collections and merge results.

### Emergency Delete (1)

**deleteEmergency** — Added DELETE endpoint that removes from both `emergencies` and `sosalerts` collections. Dashboard has 🗑️ icon button on each emergency row. Uses `btn-icon` CSS class.

---

## 14. TROUBLESHOOTING

### Dashboard empty subwindows

1. Hard refresh: Ctrl+Shift+R / Cmd+Shift+R
2. Check CF cache: `curl -sI 'https://birapp.dpdns.org/js/app.js?v=20260618' | grep cf-cache`
   - Should show BYPASS
3. If HIT -> update cache buster in index.html

### Services down

```bash
docker exec studentesp32 bash -c '/var/www/start.sh restart'
```

### Cloudflare tunnel down

```bash
docker exec studentesp32 pm2 restart cloudflare-tunnel
```

### MongoDB down

```bash
docker exec studentesp32 mongod --dbpath /data/db --fork --logpath /var/log/mongod.log
```

### Backend not loading changes

```bash
docker exec studentesp32 pm2 restart medical-master
```

### Check all services

```bash
docker exec studentesp32 bash -c '/var/www/start.sh status'
```

---

## 15. SYNC VERIFICATION RESULTS (2026-06-15 22:40)

All 9 tests PASS after full start.sh restart:

| # | Test | Status |
|---|------|--------|
| 1 | Auth (admin, patient, nurse) | PASS |
| 2 | ESP32 -> Backend (vitals/arduino) | PASS |
| 3 | Backend -> MongoDB (16 vitals stored) | PASS |
| 4 | Dashboard API (5 endpoints) | PASS |
| 5 | Flutter Patient (SOS + alerts) | PASS |
| 6 | Flutter Nurse (patients + alerts) | PASS |
| 7 | Emergency delete (DELETE /emergency/:id) | PASS |
| 8 | Dashboard via Cloudflare (3 files) | PASS |
| 9 | Socket.io real-time (vitals:update) | PASS |

### Known Gaps

- Patient has no assigned nurse (expected, no assignment made)
- Nurse my-patients returns empty (no patients assigned to nurse)

---

## 16. SESSION HISTORY

### Session 1 (2026-06-14 to 2026-06-15 morning)
- Initial setup, backend, Flutter, dashboard, Cloudflare

### Session 2 (2026-06-15 afternoon)
- 12 real-time Socket.io fixes
- 6 dashboard bug fixes
- Container cleanup (freed ~10.5GB)

### Session 3 (2026-06-15 evening)
- Dashboard empty subwindows -> root cause: Cloudflare caching old app.js
- Fix: updated cache buster + nginx no-cache headers
- Flattened project structure
- Added cloudflare-tunnel to PM2

### Session 4 (2026-06-15 night)
- Full synchronization verification (all PASS)
- Fixed emergency sync gap: emergencyController.js now queries both sosalerts AND emergencies
- Nurse password reset to nurse123
- Registered test patient (sync@test.com / sync123)
- All 25 fixes documented

### Session 5 (2026-06-15 late night)
- Added emergency delete feature (DELETE /api/v1/emergency/:id)
- Added deleteEmergency() to dashboard with "Supprimer" button on each row
- Full restart with start.sh — all services verified running
- Complete 9-test sync verification — all PASS
- Cache buster updated to v=20260617
- Total fixes: 26

### Session 6 (2026-06-15 night)
- Changed emergency delete button from text to trash icon (🗑️)
- Fixed deleteEmergency() function — was missing from app.js, now added
- Added btn-icon CSS class for icon buttons
- Full restart with start.sh — all 5 services verified
- Complete 9-test sync verification — all PASS
- Cache buster updated to v=20260618
- Total fixes: 27

---

## 17. NEXT STEPS / TODO

1. Assign nurse to patient for full nurse-patient flow
2. Create test appointments, messages, tasks for full testing
3. Build Flutter APK on host machine
4. Test Flutter app against live birapp.dpdns.org backend
5. Fix phone validation (Moroccan format 05/06/07 + 10 digits) — blocks signup
6. Email OTP config needed (EMAIL_USER/EMAIL_PASS in .env) — blocks verified signup
