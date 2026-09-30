// Polls compartment schedules and fires an automatic dispense the first
// time the clock matches a compartment's configured time each day.

import { store } from "./store.js";
import { dispenseCompartment } from "./doseActions.js";

const CHECK_INTERVAL_MS = 12_000;

export function startScheduler(broadcast) {
  setInterval(() => checkSchedules(broadcast), CHECK_INTERVAL_MS);
  console.log(
    `[Scheduler] Watching compartment schedules every ${CHECK_INTERVAL_MS / 1000}s`,
  );
}

function todayStr() {
  return new Date().toISOString().slice(0, 10);
}

function currentHm() {
  const now = new Date();
  return `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
}

async function checkSchedules(broadcast) {
  const date = todayStr();
  const hm = currentHm();

  for (const compartment of store.getCompartments()) {
    if (compartment.time !== hm) continue;
    if (store.findTodayEvent(compartment.id, date)) continue;

    console.log(
      `[Scheduler] Scheduled time reached for compartment ${compartment.id} (${compartment.label})`,
    );
    try {
      await dispenseCompartment(compartment.id, broadcast);
    } catch (err) {
      console.log(
        `[Scheduler] Failed to dispense compartment ${compartment.id}: ${err.message}`,
      );
    }
  }
}
