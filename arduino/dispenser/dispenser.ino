// MedTrack Bridge - Arduino dispenser sketch
//
// Listens on Serial (115200 baud) for line-terminated commands and drives
// two SG90 servos (one per medicine compartment).
//
// Compartment 1 (servo1): opens to 90°, holds, closes back to 0°.
// Compartment 2 (servo2): mounted the opposite way round — opens to 90°
//   from a 180° rest (a mirrored 90° swing), holds longer, closes back to
//   180°.
//
// Command:  "DISPENSE <id>\n"       timed dispense — opens, holds, closes
//                                    and reports DONE automatically.
//           "TESTDISPENSE <id>\n"   manual-test dispense — opens and STAYS
//                                    open (no auto-close, no DONE yet)
//                                    until a matching "COLLECT <id>"
//                                    arrives.
//           "COLLECT <id>\n"        closes a compartment left open by
//                                    TESTDISPENSE and reports DONE. Ignored
//                                    if that compartment isn't waiting.
// Replies:  "ACK DISPENSE <id>\n"   sent the moment DISPENSE/TESTDISPENSE
//                                   is accepted
//           "DONE DISPENSE <id>\n"  sent once the servo is back at rest
//
// Malformed or unrecognized input is ignored rather than crashing.

#include <Servo.h>

const uint8_t SERVO1_PIN = 9;
const uint8_t SERVO2_PIN = 10;

const uint8_t SERVO1_REST = 0;
const uint8_t SERVO1_OPEN = 90;
const uint16_t SERVO1_HOLD_MS = 1200;

// Servo2 is mounted the opposite way round from servo1, so its open
// motion runs the opposite direction: rest at 180°, open at 90° (a
// mirrored 90° swing rather than the same 0->90 as servo1).
const uint8_t SERVO2_REST = 180;
const uint8_t SERVO2_OPEN = 90;
const uint16_t SERVO2_HOLD_MS = 5000;

const uint32_t SERIAL_BAUD = 115200;
// Longest valid command ("TESTDISPENSE 1") is well under this; caps how
// much we'll buffer before giving up on a line, so noise on the line can't
// grow the buffer forever.
const uint8_t MAX_LINE_LEN = 32;

Servo servo1;
Servo servo2;

char lineBuf[MAX_LINE_LEN];
uint8_t lineLen = 0;

// 0 = nothing waiting on a manual COLLECT. Set by TESTDISPENSE, cleared by
// a matching COLLECT.
uint8_t pendingCollection = 0;

void setup() {
  Serial.begin(SERIAL_BAUD);

  servo1.attach(SERVO1_PIN);
  servo1.write(SERVO1_REST);

  servo2.attach(SERVO2_PIN);
  servo2.write(SERVO2_REST);
}

void loop() {
  readSerialLine();
}

// Accumulates incoming bytes into lineBuf and hands off complete lines
// (terminated by '\n') to handleCommand. Using a fixed char buffer instead
// of Serial.readStringUntil/String avoids heap fragmentation from repeated
// String allocation, which matters for a device meant to stay powered on
// for the whole demo (and beyond).
void readSerialLine() {
  while (Serial.available()) {
    char c = Serial.read();

    if (c == '\r') {
      continue;
    }

    if (c == '\n') {
      lineBuf[lineLen] = '\0';
      if (lineLen > 0) {
        handleCommand(lineBuf);
      }
      lineLen = 0;
      continue;
    }

    if (lineLen < MAX_LINE_LEN - 1) {
      lineBuf[lineLen++] = c;
    } else {
      // Line too long to be a valid command; drop it and resync on the
      // next newline instead of overflowing the buffer.
      lineLen = 0;
    }
  }
}

void handleCommand(char *cmd) {
  int id = 0;

  if (parseWithPrefix(cmd, "TESTDISPENSE ", &id)) {
    if (id == 1) {
      runDispenseHold(1, servo1, SERVO1_OPEN);
    } else if (id == 2) {
      runDispenseHold(2, servo2, SERVO2_OPEN);
    }
    return;
  }

  if (parseWithPrefix(cmd, "DISPENSE ", &id)) {
    if (id == 1) {
      runDispenseTimed(1, servo1, SERVO1_REST, SERVO1_OPEN, SERVO1_HOLD_MS);
    } else if (id == 2) {
      runDispenseTimed(2, servo2, SERVO2_REST, SERVO2_OPEN, SERVO2_HOLD_MS);
    }
    return;
  }

  if (parseWithPrefix(cmd, "COLLECT ", &id)) {
    // Ignored if that compartment isn't actually waiting (e.g. a stray
    // COLLECT after a timed DISPENSE that already closed itself).
    if (pendingCollection == id) {
      pendingCollection = 0;
      closeCompartment(id);
    }
    return;
  }

  // Anything else is ignored rather than crashing.
}

// Matches "<prefix><n>" where <n> is one or more digits, with no other
// trailing characters. Returns true and sets *outId on a match.
bool parseWithPrefix(const char *cmd, const char *prefix, int *outId) {
  size_t prefixLen = strlen(prefix);

  if (strncmp(cmd, prefix, prefixLen) != 0) {
    return false;
  }

  const char *digits = cmd + prefixLen;
  if (*digits == '\0') {
    return false;
  }

  int value = 0;
  for (const char *p = digits; *p != '\0'; p++) {
    if (*p < '0' || *p > '9') {
      return false;
    }
    value = value * 10 + (*p - '0');
  }

  *outId = value;
  return true;
}

void closeCompartment(int id) {
  if (id == 1) {
    servo1.write(SERVO1_REST);
  } else if (id == 2) {
    servo2.write(SERVO2_REST);
  }
  Serial.print("DONE DISPENSE ");
  Serial.println(id);
}

// Scheduled/normal dispense: opens, holds, closes and reports DONE on its
// own — no user interaction needed.
void runDispenseTimed(int id, Servo &s, uint8_t restAngle, uint8_t openAngle, uint16_t holdMs) {
  Serial.print("ACK DISPENSE ");
  Serial.println(id);

  s.write(openAngle);
  delay(holdMs);
  s.write(restAngle);

  Serial.print("DONE DISPENSE ");
  Serial.println(id);
}

// Manual test dispense (the "Simulate dispense" button): opens and stays
// open — closeCompartment() only runs once a matching COLLECT arrives.
void runDispenseHold(int id, Servo &s, uint8_t openAngle) {
  Serial.print("ACK DISPENSE ");
  Serial.println(id);

  s.write(openAngle);
  pendingCollection = id;
}
