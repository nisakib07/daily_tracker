import { GoogleGenAI } from "@google/genai";

// The lightest current Gemini "Flash" tier, listed as free-of-charge on
// the Gemini API pricing page and explicitly present in the SDK's model
// union - good enough for structured, low-latency suggestion generation.
export const GEMINI_MODEL = "gemini-2.5-flash";

let client: GoogleGenAI | null = null;

/**
 * Lazily constructs the shared Gemini client. Throws if GEMINI_API_KEY
 * isn't configured, so callers (the API routes) can catch this and
 * respond with a clear error instead of the SDK failing deep inside a
 * request.
 */
export function getGeminiClient(): GoogleGenAI {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is not configured on the server.");
  }

  if (!client) {
    client = new GoogleGenAI({ apiKey });
  }
  return client;
}
