import { GoogleGenAI } from "@google/genai";

// "gemini-2.5-flash" was pinned here originally, but Google retired it for
// new API keys ("no longer available to new users") - confirmed via a
// live 404 from the Interactions API, not training data. Using the
// "-latest" alias instead of a dated version avoids re-hitting this exact
// problem when the pinned model eventually gets deprecated again; it's
// explicitly present in the SDK's model union and stays on the free Flash
// tier.
export const GEMINI_MODEL = "gemini-flash-latest";

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
