import { createClient } from "@supabase/supabase-js";

/**
 * Verifies the caller's Supabase access token from the Authorization
 * header. Used by the AI routes, which the mobile app calls directly
 * (no cookies) - this is the bearer-token equivalent of the cookie-based
 * session check the web app gets for free from middleware.
 */
export async function verifyUser(request: Request): Promise<{ id: string } | null> {
  const authHeader = request.headers.get("authorization");
  const token = authHeader?.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!token) return null;

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) return null;

  return { id: data.user.id };
}
