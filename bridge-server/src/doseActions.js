// Shared dose lifecycle logic used by both the manual POST /api/dispense
// endpoint and the background scheduler, so the two paths can't drift.

import { store } from "./store.js";
import { dispense as serialDispense } from "./serial.js";

const MISSED_TIMEOUT_MS = 2 * 60 * 1000;
const missedTimers = new Map();

function todayStr() {
  return new Date().toISOString().slice(0, 10);
}

export async function dispenseCompartment(compartmentId, broadcast) {
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

  await serialDispense(compartmentId);

  const doneEvent = store.getEvent(event.id);
  broadcast({ type: "done", event: doneEvent });

  scheduleMissedCheck(event.id, broadcast);
  return doneEvent;
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
  return updated;
}
