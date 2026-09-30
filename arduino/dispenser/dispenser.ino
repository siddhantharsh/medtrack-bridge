// MedTrack Bridge - Arduino dispenser sketch
//
// Listens on Serial (115200 baud) for line-terminated commands and drives
// two SG90 servos (one per medicine compartment). Each dispense cycle
// acknowledges immediately, then reports completion once the servo has
// finished its sweep.
//
// Command:  "DISPENSE <id>\n"   id is 1 or 2
// Replies:  "ACK DISPENSE <id>\n"   sent the moment the command is accepted
//           "DONE DISPENSE <id>\n"  sent after the servo returns to rest
//
// Malformed or unrecognized input is ignored rather than crashing.

#include <Servo.h>

const uint8_t SERVO1_PIN = 9;
const uint8_t SERVO2_PIN = 10;

const uint8_t ANGLE_REST = 0;
const uint8_t ANGLE_OPEN = 90;
const uint16_t OPEN_HOLD_MS = 1200;

const uint8_t SERIAL_BAUD = 115200;
// Longest valid command ("DISPENSE 1") is well under this; caps how much
// we'll buffer before giving up on a line, so noise on the line can't
// grow the buffer forever.
const uint8_t MAX_LINE_LEN = 32;

Servo servo1;
Servo servo2;

char lineBuf[MAX_LINE_LEN];
uint8_t lineLen = 0;

void setup() {
  Serial.begin(SERIAL_BAUD);

  servo1.attach(SERVO1_PIN);
  servo1.write(ANGLE_REST);

  servo2.attach(SERVO2_PIN);
  servo2.write(ANGLE_REST);
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
  if (parseDispense(cmd, &id)) {
    if (id == 1) {
      runDispense(1, servo1);
    } else if (id == 2) {
      runDispense(2, servo2);
    }
    // Any other id is out of range for this hardware; ignore silently.
  }
  // Anything that isn't "DISPENSE <id>" is ignored rather than crashing.
}

// Matches "DISPENSE <n>" where <n> is one or more digits, with no other
// trailing characters. Returns true and sets *outId on a match.
bool parseDispense(const char *cmd, int *outId) {
  const char *prefix = "DISPENSE ";
  const size_t prefixLen = 9;

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

void runDispense(int id, Servo &s) {
  Serial.print("ACK DISPENSE ");
  Serial.println(id);

  s.write(ANGLE_OPEN);
  delay(OPEN_HOLD_MS);
  s.write(ANGLE_REST);

  Serial.print("DONE DISPENSE ");
  Serial.println(id);
}
