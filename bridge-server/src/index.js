import "dotenv/config";
import express from "express";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { connectArduino, isConnected } from "./serial.js";
import { createBroadcastHub } from "./ws.js";
import { createRouter } from "./routes.js";
import { startScheduler } from "./scheduler.js";
import { store } from "./store.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PORT = Number(process.env.PORT) || 3000;
const ARDUINO_PORT = process.env.ARDUINO_PORT || null;
const ARDUINO_BAUD = Number(process.env.ARDUINO_BAUD) || 115200;

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, "..", "public")));

const server = http.createServer(app);
const broadcast = createBroadcastHub(server);

app.use(createRouter(broadcast));

async function main() {
  if (store.getCompartments().length === 0) {
    store.upsertCompartment({
      id: 1,
      label: "Compartment 1",
      medicineName: "Medicine A",
      time: "08:00",
    });
    store.upsertCompartment({
      id: 2,
      label: "Compartment 2",
      medicineName: "Medicine B",
      time: "20:00",
    });
    console.log(
      "[Store] Seeded default compartments (edit via POST /api/compartments)",
    );
  }

  await connectArduino({ configuredPath: ARDUINO_PORT, baudRate: ARDUINO_BAUD });
  startScheduler(broadcast);

  server.listen(PORT, () => {
    console.log(`[Bridge] Listening on http://0.0.0.0:${PORT}`);
    console.log(`[Bridge] Status page: http://<laptop-ip>:${PORT}/`);
    console.log(
      `[Bridge] Arduino: ${isConnected() ? "connected" : "not connected yet"}`,
    );
  });
}

main();
