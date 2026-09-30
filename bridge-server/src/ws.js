// WebSocket hub: pushes every dose state change to all connected clients
// (phone app + laptop status page) in real time.

import { WebSocketServer } from "ws";

export function createBroadcastHub(server) {
  const wss = new WebSocketServer({ server });

  wss.on("connection", (ws) => {
    console.log("[WS] Client connected");
    ws.on("close", () => console.log("[WS] Client disconnected"));
  });

  return function broadcast(message) {
    const payload = JSON.stringify(message);
    for (const client of wss.clients) {
      if (client.readyState === client.OPEN) {
        client.send(payload);
      }
    }
  };
}
