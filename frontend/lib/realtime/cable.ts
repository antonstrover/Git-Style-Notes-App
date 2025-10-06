import { createConsumer, Consumer } from "@rails/actioncable";

let consumer: Consumer | null = null;
let consumerPromise: Promise<Consumer> | null = null;
let reconnectAttempts = 0;
const MAX_RECONNECT_ATTEMPTS = 10;
const BASE_RECONNECT_DELAY = 1000; // ms

/**
 * Get or create the Action Cable consumer instance
 * Fetches WebSocket URL and auth token from server
 */
export async function getCableConsumer(): Promise<Consumer> {
  if (consumer) {
    return consumer;
  }

  // Prevent multiple simultaneous initialization attempts
  if (consumerPromise) {
    return consumerPromise;
  }

  consumerPromise = initializeConsumer();
  consumer = await consumerPromise;
  consumerPromise = null;

  return consumer;
}

async function initializeConsumer(): Promise<Consumer> {
  // Fetch WebSocket URL and auth from server
  const wsUrl = await getWebSocketUrl();

  const newConsumer = createConsumer(wsUrl);

  // Add reconnection logic
  newConsumer.connection.on("connected", () => {
    console.log("[ActionCable] Connected to WebSocket");
    reconnectAttempts = 0;
  });

  newConsumer.connection.on("disconnected", () => {
    console.log("[ActionCable] Disconnected from WebSocket");
    handleReconnect();
  });

  newConsumer.connection.on("rejected", () => {
    console.error("[ActionCable] Connection rejected (auth failed?)");
  });

  return newConsumer;
}

/**
 * Disconnect and reset the cable consumer
 */
export function disconnectCable() {
  if (consumer) {
    consumer.disconnect();
    consumer = null;
    reconnectAttempts = 0;
  }
}

/**
 * Get the WebSocket URL for Action Cable
 * Fetches auth token from Next.js API (which has access to HttpOnly cookies)
 */
async function getWebSocketUrl(): Promise<string> {
  if (typeof window === "undefined") {
    // Server-side rendering
    throw new Error("Cannot initialize Action Cable on server side");
  }

  try {
    // Fetch WebSocket URL and auth token from our API endpoint
    const response = await fetch("/api/cable-auth");

    if (!response.ok) {
      throw new Error("Failed to get cable auth");
    }

    const { url, authToken } = await response.json();

    // Append auth token to URL
    // Rails Action Cable will receive this in the connection request
    const wsUrl = new URL(url);
    wsUrl.searchParams.set("token", authToken);

    return wsUrl.toString();
  } catch (error) {
    console.error("[ActionCable] Failed to get WebSocket URL:", error);
    // Fallback to default URL without auth
    return process.env.NEXT_PUBLIC_BACKEND_WS_URL || "ws://localhost:3000/cable";
  }
}

/**
 * Handle reconnection with exponential backoff
 */
function handleReconnect() {
  if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
    console.error("[ActionCable] Max reconnection attempts reached");
    return;
  }

  reconnectAttempts++;
  const delay = Math.min(
    BASE_RECONNECT_DELAY * Math.pow(2, reconnectAttempts - 1),
    30000 // Max 30s delay
  );

  console.log(
    `[ActionCable] Reconnecting in ${delay}ms (attempt ${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})`
  );

  setTimeout(() => {
    if (consumer) {
      consumer.connect();
    }
  }, delay);
}
