import { NextResponse } from "next/server";

/**
 * The Flutter mobile app calls these routes directly from a browser context
 * when running as Flutter web (dev server, or a future web build) - a
 * different origin than the deployed API. Native Android/iOS builds aren't
 * subject to CORS, but browser-hosted testing is, so every response here
 * needs these headers or the browser silently blocks it before our code
 * ever runs.
 */
function corsHeaders(request: Request): HeadersInit {
  const origin = request.headers.get("origin");
  return {
    "Access-Control-Allow-Origin": origin ?? "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    Vary: "Origin",
  };
}

export function corsJson(
  request: Request,
  body: unknown,
  init?: { status?: number },
) {
  return NextResponse.json(body, {
    status: init?.status,
    headers: corsHeaders(request),
  });
}

export function corsPreflight(request: Request) {
  return new NextResponse(null, { status: 204, headers: corsHeaders(request) });
}
