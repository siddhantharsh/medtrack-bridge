// Shared dose lifecycle logic used by both the manual POST /api/dispense
// endpoint and the background scheduler, so the two paths can't drift.

import { store } from "./store.js";
import { dispense as serialDispense, collect as serialCollect } from "./serial.js";

const MISSED_TIMEOUT_MS = 2 * 60 * 1000;
const missedTimers = new Map();

function todayStr() {
  return new Date().toISOString().slice(0, 10);
}

// manual: true for the "Simulate dispense" button (phone or laptop UI) —
// the servo opens and stays open until collectDose() is called, rather
// than auto-closing on a timer. false for the scheduler's real dispenses.
export async function dispenseCompartment(compartmentId, broadcast, { manual = false } = {}) {
  const compartment = store.getCompartment(compartmentId);
  if (!compartment) {
    throw new Error(`Unknown compartment ${compartmentId}`);
  }

  const date = todayStr();
  const event = store.addDoseEvent({
    compartmentId,
    date,
    status: "dispensed",
  });
  broadcast({ type: "dispensed", event });
  scheduleMissedCheck(event.id, broadcast);

  await serialDispense(compartmentId, { hold: manual });

  return event;
}

// Fires when the Arduino reports a servo back at rest — quickly for a
// timed dispense, or whenever collectDose() closes a held-open one. Purely
// informational (e.g. drives the laptop UI's beep); doesn't change status.
export function notifyDone(compartmentId, broadcast) {
  const event = store.findLatestDispensedToday(compartmentId, todayStr());
  if (event) {
    broadcast({ type: "done", event });
  }
}

function scheduleMissedCheck(eventId, broadcast) {
  const timer = setTimeout(() => {
    missedTimers.delete(eventId);
    const current = store.getEvent(eventId);
    if (current && current.status === "dispensed") {
      const updated = store.updateDoseEvent(eventId, { status: "missed" });
      console.log(
        `[Scheduler] Compartment ${updated.compartmentId} dose (event #${updated.id}) marked missed`,
      );
      broadcast({ type: "missed", event: updated });
    }
  }, MISSED_TIMEOUT_MS);
  missedTimers.set(eventId, timer);
}

export function collectDose(compartmentId, broadcast) {
  const date = todayStr();
  const event = store.findLatestDispensedToday(compartmentId, date);
  if (!event) {
    throw new Error(
      "No pending dose to collect for this compartment today",
    );
  }

  const timer = missedTimers.get(event.id);
  if (timer) {
    clearTimeout(timer);
    missedTimers.delete(event.id);
  }

  const updated = store.updateDoseEvent(event.id, { status: "collected" });
  broadcast({ type: "collected", event: updated });

  // No-op on the Arduino side if that compartment wasn't actually held
  // open (e.g. a timed dispense that already closed itself).
  serialCollect(compartmentId);

  return updated;
}
