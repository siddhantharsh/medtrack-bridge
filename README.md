# MedTrack Bridge — Smart Medical Dispenser (Phase 2)

Laptop-to-Arduino relay for the MedTrack companion app. The laptop stands in
for the cloud: it receives commands from the phone over the local WiFi
network and relays them to an Arduino Uno over USB serial.

```
Phone (Flutter app)  --HTTP + WebSocket, same LAN-->  Laptop (Node.js bridge)
                                                            --USB serial-->
                                              Arduino Uno --PWM--> 2x SG90 servos
```

- `/arduino` — Arduino sketch that drives the two compartment servos
- `/bridge-server` — Node.js/Express relay: REST API, WebSocket broadcast,
  scheduler, and a local status page
- `/mobile-app` — Flutter companion app (Home / Schedule / History / Settings)

## 1. Arduino sketch

`arduino/dispenser/dispenser.ino` listens on Serial at **115200 baud** for
`DISPENSE <id>\n` (id 1 or 2), replies `ACK DISPENSE <id>`, sweeps that
compartment's servo from 0° to 90° and back (1200ms hold), then replies
`DONE DISPENSE <id>`.

**Wiring:** servo 1 signal → pin 9, servo 2 signal → pin 10. Power the
servos from the Arduino's 5V/GND (or an external 5V supply with a shared
ground) — two SG90s can brown out the USB-powered 5V rail under load.

**Upload:**
1. Open `arduino/dispenser/dispenser.ino` in the Arduino IDE (or `arduino-cli`).
2. Select **Board → Arduino Uno** and the correct **Port**.
3. Click **Upload**.
4. Open the Serial Monitor at 115200 baud to sanity-check — you can type
   `DISPENSE 1` and press enter to see `ACK DISPENSE 1` / `DONE DISPENSE 1`.

## 2. Bridge server

```
cd bridge-server
npm install
cp .env.example .env   # edit ARDUINO_PORT if auto-detect doesn't find it
npm start
```

The server:
- Auto-detects the Arduino's serial port on startup (falls back to
  `ARDUINO_PORT` in `.env` if set, e.g. `/dev/ttyUSB0` or `/dev/ttyACM0`).
- Serves a REST API + WebSocket on `PORT` (default `3000`).
- Serves a live status page at `GET /`.
- Seeds two default compartments on first run (edit via `POST /api/compartments`).

**Console output to watch for during the demo:**
```
[Arduino] Connected on /dev/ttyACM0
[Bridge] Listening on http://0.0.0.0:3000
[Bridge] Status page: http://<laptop-ip>:3000/
[Arduino] DISPENSE 1 acknowledged
[Arduino] DISPENSE 1 complete
```

### REST API
| Method | Path                 | Body                                    | Notes |
|--------|----------------------|------------------------------------------|-------|
| GET    | `/api/compartments`  | —                                        | List configured compartments |
| POST   | `/api/compartments`  | `{ id, label, medicineName, time }`      | Create/update a compartment |
| POST   | `/api/dispense`      | `{ compartmentId }`                      | Sends `DISPENSE <id>`, waits for ACK/DONE, returns the DoseEvent |
| POST   | `/api/collect`       | `{ compartmentId }`                      | Marks today's dispensed dose as collected |
| GET    | `/api/history`       | —                                        | All DoseEvents, newest first |
| GET    | `/api/status`        | —                                        | `{ arduinoConnected }` |

### Finding the laptop's local IP (to enter in the phone app's Settings)

```
# macOS / Linux
ipconfig getifaddr en0        # macOS WiFi
hostname -I                   # Linux (pick the LAN address, not 127.0.0.1)

# Windows
ipconfig                      # look for "IPv4 Address" under your WiFi adapter
```

The **status page URL** is: `http://<laptop-ip>:3000/`

## 3. Mobile app (Flutter)

```
cd mobile-app
flutter pub get
flutter build apk --debug     # or: flutter run, with a device/emulator attached
```

> **JDK note:** if `flutter build apk` fails with a `jlink` /
> `core-for-system-modules.jar` error, your default JDK is too new for the
> Android Gradle Plugin's toolchain (this happened on this machine with JDK
> 27). Install JDK 21 and point `JAVA_HOME` at it for the build:
> `JAVA_HOME=/path/to/jdk-21 flutter build apk --debug`. Confirmed working
> here with `mise install java@21.0.2` and
> `JAVA_HOME=$(mise where java@21.0.2)`.

- **Home ("Today")** — compartment cards with live status pills; "Simulate
  dispense" and "Mark collected" buttons.
- **Schedule** — add/edit compartments (label, medicine name, time).
- **History** — event log + 7-day adherence.
- **Settings → Connect to laptop** — enter the laptop's IP + port shown
  above, tap **Test connection** (pings `GET /api/compartments`), then
  **Save & connect** to switch the app from local simulation to the real
  bridge server over HTTP + WebSocket.

Until a laptop is configured in Settings, the app runs entirely on an
in-memory `LocalDoseRepository` so the UI is usable standalone. Both
`LocalDoseRepository` and `RemoteDoseRepository` implement the same
`DoseRepository` interface (`lib/repository/dose_repository.dart`), so
swapping between them doesn't touch any screen code.

## End-to-end demo script

1. Power the Arduino (sketch already uploaded) and plug it into the laptop
   via USB.
2. `cd bridge-server && npm start` — confirm the console shows
   `[Arduino] Connected on <port>`.
3. On the laptop, open `http://localhost:3000/` — the status page should
   show both compartments as "Pending".
4. On the phone, open the MedTrack app → **Settings** → enter the laptop's
   LAN IP (from `hostname -I` / `ipconfig`) and port `3000` → **Test
   connection** should report success → **Save & connect**.
5. On **Home**, tap **Simulate dispense** on Compartment 1.
   - Phone and laptop status page both flip to "Dispensed" in real time.
   - The Arduino's compartment 1 servo sweeps open and closed.
   - Console logs `[Arduino] DISPENSE 1 acknowledged` then `... complete`.
6. Tap **Mark collected** on the phone (or wait ~2 minutes to see it flip to
   "Missed" automatically) — both UIs update live over the WebSocket.
7. Open **History** on the phone to see the event and the 7-day adherence
   figure.
8. To show the automatic scheduler: edit a compartment's time in
   **Schedule** to a minute from now and wait — the dispense fires on its
   own, no button press.
