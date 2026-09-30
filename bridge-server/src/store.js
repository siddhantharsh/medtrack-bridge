// Local persistence for the bridge server. This milestone doesn't need a
// database: state lives in memory and is dumped to a JSON file on every
// mutation so a restart doesn't lose the day's history.

import fs from "node:fs";
import path from "node:path";

const DB_PATH = path.join(process.cwd(), "data", "db.json");

function loadInitialState() {
  try {
    const raw = fs.readFileSync(DB_PATH, "utf-8");
    const parsed = JSON.parse(raw);
    return {
      compartments: parsed.compartments ?? [],
      doseEvents: parsed.doseEvents ?? [],
    };
  } catch {
    return { compartments: [], doseEvents: [] };
  }
}

const state = loadInitialState();
let nextEventId =
  state.doseEvents.reduce((max, e) => Math.max(max, e.id), 0) + 1;

function persist() {
  fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
  fs.writeFileSync(DB_PATH, JSON.stringify(state, null, 2));
}

export const store = {
  getCompartments() {
    return [...state.compartments].sort((a, b) => a.id - b.id);
  },

  getCompartment(id) {
    return state.compartments.find((c) => c.id === id) ?? null;
  },

  upsertCompartment({ id, label, medicineName, time }) {
    const idx = state.compartments.findIndex((c) => c.id === id);
    const record = { id, label, medicineName, time };
    if (idx >= 0) {
      state.compartments[idx] = record;
    } else {
      state.compartments.push(record);
    }
    persist();
    return record;
  },

  getHistory() {
    return [...state.doseEvents].sort((a, b) => b.id - a.id);
  },

  getEvent(id) {
    return state.doseEvents.find((e) => e.id === id) ?? null;
  },

  addDoseEvent({ compartmentId, date, status }) {
    const event = {
      id: nextEventId++,
      compartmentId,
      date,
      status,
      updatedAt: new Date().toISOString(),
    };
    state.doseEvents.push(event);
    persist();
    return event;
  },

  updateDoseEvent(id, changes) {
    const event = state.doseEvents.find((e) => e.id === id);
    if (!event) return null;
    Object.assign(event, changes, { updatedAt: new Date().toISOString() });
    persist();
    return event;
  },

  findTodayEvent(compartmentId, date) {
    return (
      state.doseEvents.find(
        (e) => e.compartmentId === compartmentId && e.date === date,
      ) ?? null
    );
  },

  findLatestDispensedToday(compartmentId, date) {
    return (
      [...state.doseEvents]
        .reverse()
        .find(
          (e) =>
            e.compartmentId === compartmentId &&
            e.date === date &&
            e.status === "dispensed",
        ) ?? null
    );
  },
};
