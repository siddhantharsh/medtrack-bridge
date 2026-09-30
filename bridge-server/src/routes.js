import { Router } from "express";
import os from "node:os";
import { store } from "./store.js";
import { dispenseCompartment, collectDose } from "./doseActions.js";
import { isConnected } from "./serial.js";

// Picks a LAN-reachable IPv4 address to show on the status page, so it can
// be typed straight into the phone app's Settings. Skips loopback and
// virtual/container interfaces that a phone couldn't actually reach.
export function localIp() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    if (/^(lo|docker|veth|br-)/.test(name)) continue;
    for (const iface of interfaces[name] ?? []) {
      if (iface.family === "IPv4" && !iface.internal) {
        return iface.address;
      }
    }
  }
  return null;
}

export function createRouter(broadcast, { port }) {
  const router = Router();

  router.get("/api/status", (req, res) => {
    res.json({ arduinoConnected: isConnected(), localIp: localIp(), port });
  });

  router.get("/api/compartments", (req, res) => {
    res.json(store.getCompartments());
  });

  router.post("/api/compartments", (req, res) => {
    const { id, label, medicineName, time } = req.body || {};
    if (!id || !label || !medicineName || !time) {
      return res
        .status(400)
        .json({ error: "id, label, medicineName, and time are required" });
    }
    const compartment = store.upsertCompartment({
      id: Number(id),
      label,
      medicineName,
      time,
    });
    broadcast({ type: "compartments-updated", compartments: store.getCompartments() });
    res.json(compartment);
  });

  router.post("/api/dispense", async (req, res) => {
    const { compartmentId } = req.body || {};
    if (!compartmentId) {
      return res.status(400).json({ error: "compartmentId is required" });
    }
    if (!isConnected()) {
      return res.status(503).json({ error: "Arduino is not connected" });
    }

    try {
      // The HTTP API is the "Simulate dispense" entry point (phone app and
      // laptop UI both call it), so it always uses the manual/hold-open
      // behavior — the scheduler calls dispenseCompartment() directly for
      // the real timed dispenses.
      const event = await dispenseCompartment(Number(compartmentId), broadcast, {
        manual: true,
      });
      res.json(event);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  router.post("/api/collect", (req, res) => {
    const { compartmentId } = req.body || {};
    if (!compartmentId) {
      return res.status(400).json({ error: "compartmentId is required" });
    }

    try {
      const event = collectDose(Number(compartmentId), broadcast);
      res.json(event);
    } catch (err) {
      res.status(400).json({ error: err.message });
    }
  });

  router.get("/api/history", (req, res) => {
    res.json(store.getHistory());
  });

  return router;
}
