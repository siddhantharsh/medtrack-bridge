// USB serial link to the Arduino. Handles auto-detecting the port,
// logging connection status, and matching outgoing dispense commands to
// the Arduino's ACK/DONE replies.

import { SerialPort, ReadlineParser } from "serialport";

// Opening the serial port resets the Arduino (DTR toggle), and the board's
// bootloader/UART needs a moment to settle afterward. Any byte written
// during that window is silently swallowed — observed as the first command
// sent right after 'open' never getting a reply. Wait this long, then send
// a harmless warm-up line (ignored by the sketch, since it isn't a valid
// command) to absorb that loss before accepting real commands.
const BOOT_SETTLE_MS = 2500;

let port = null;
let ready = false;
let pending = null; // { compartmentId, resolve, timer }
let doneHandler = null; // (compartmentId) => void, set via onDone()

export async function connectArduino({ configuredPath, baudRate }) {
  const targetPath = configuredPath || (await autoDetectPort());

  if (!targetPath) {
    console.log(
      "[Arduino] No serial port found. Plug in the Arduino, or set ARDUINO_PORT in .env and restart.",
    );
    return null;
  }

  port = new SerialPort({ path: targetPath, baudRate });
  const parser = port.pipe(new ReadlineParser({ delimiter: "\n" }));

  port.on("open", () => {
    console.log(`[Arduino] Port opened on ${targetPath}, waiting for board to reset...`);
    setTimeout(() => {
      port.write("\n", () => {
        ready = true;
        console.log(`[Arduino] Connected on ${targetPath}`);
      });
    }, BOOT_SETTLE_MS);
  });

  port.on("error", (err) => {
    console.log(`[Arduino] Serial error: ${err.message}`);
  });

  port.on("close", () => {
    ready = false;
    console.log("[Arduino] Serial port closed");
  });

  parser.on("data", handleLine);

  return port;
}

async function autoDetectPort() {
  const ports = await SerialPort.list();
  const match = ports.find(
    (p) =>
      /arduino/i.test(p.manufacturer || "") ||
      /wch|ch340|ftdi|usb-serial|silicon labs/i.test(p.manufacturer || "") ||
      /usbmodem|usbserial|ttyusb|ttyacm/i.test(p.path.toLowerCase()),
  );
  return match ? match.path : null;
}

function handleLine(rawLine) {
  const line = rawLine.trim();
  if (!line) return;

  if (line.startsWith("ACK DISPENSE ")) {
    const id = Number(line.slice("ACK DISPENSE ".length));
    console.log(`[Arduino] DISPENSE ${id} acknowledged`);
    if (pending && pending.compartmentId === id) {
      pending.resolve();
      pending = null;
    }
    return;
  }

  if (line.startsWith("DONE DISPENSE ")) {
    const id = Number(line.slice("DONE DISPENSE ".length));
    console.log(`[Arduino] DISPENSE ${id} complete`);
    doneHandler?.(id);
    return;
  }

  console.log(`[Arduino] ${line}`);
}

// Registers a callback fired whenever the Arduino reports a compartment's
// servo is back at rest — for a timed dispense this follows quickly; for a
// manual-test dispense (see dispense()'s `hold` option) it only fires once
// collect() is called, which could be much later.
export function onDone(handler) {
  doneHandler = handler;
}

// Sends a dispense command and resolves once the Arduino's ACK for that id
// comes back (or rejects on timeout / disconnect). Physical completion
// (DONE) arrives later and asynchronously — see onDone() — since a
// manual-test dispense holds open indefinitely until collect() is called.
// Only one dispense can be in flight at a time, matching the Arduino's
// single-threaded loop.
export function dispense(compartmentId, { hold = false, timeoutMs = 5000 } = {}) {
  if (!port || !port.isOpen) {
    return Promise.reject(new Error("Arduino is not connected"));
  }
  if (!ready) {
    return Promise.reject(
      new Error("Arduino is still resetting after connecting, try again in a couple seconds"),
    );
  }
  if (pending) {
    return Promise.reject(
      new Error("Another dispense is already in progress"),
    );
  }

  const command = hold ? "TESTDISPENSE" : "DISPENSE";

  return new Promise((resolve, reject) => {
    // This native serialport binding doesn't reliably deliver 'data'
    // events on its own on this system — buffered replies only surface
    // once another write happens (confirmed via direct testing: a stuck
    // read only flushes right after a subsequent port.write()). Nudge
    // with a harmless newline periodically so the ACK gets delivered
    // promptly instead of sitting buffered until something else pokes it.
    const nudge = setInterval(() => port.write("\n"), 250);

    pending = {
      compartmentId,
      resolve: () => {
        clearInterval(nudge);
        clearTimeout(pending.timer);
        resolve();
      },
      timer: setTimeout(() => {
        clearInterval(nudge);
        pending = null;
        reject(
          new Error(
            `Timed out waiting for Arduino response to ${command} ${compartmentId}`,
          ),
        );
      }, timeoutMs),
    };

    port.write(`${command} ${compartmentId}\n`, (err) => {
      if (err) {
        clearInterval(nudge);
        clearTimeout(pending.timer);
        pending = null;
        reject(err);
      }
    });
  });
}

// Closes a compartment left open by a manual-test dispense. Best-effort:
// if the Arduino isn't connected, the DB-side collect still succeeds, it
// just won't physically close until it reconnects.
export function collect(compartmentId) {
  if (port && port.isOpen) {
    port.write(`COLLECT ${compartmentId}\n`);
  }
}

export function isConnected() {
  return Boolean(port && port.isOpen && ready);
}
