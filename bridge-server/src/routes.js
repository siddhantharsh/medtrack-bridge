import { Router } from "express";
import { store } from "./store.js";
import { dispenseCompartment, collectDose } from "./doseActions.js";
import { isConnected } from "./serial.js";

export function createRouter(broadcast) {
  const router = Router();

  router.get("/api/status", (req, res) => {
    res.json({ arduinoConnected: isConnected() });
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
      const event = await dispenseCompartment(Number(compartmentId), broadcast);
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
