// POST /functions/v1/leave-household
// Removes the calling user from their household and revokes their refresh tokens.
// Their current JWT is valid until expiry (~1hr) but cannot be refreshed —
// the iOS app receives a 401 on the next token refresh and redirects to login.
//
// Body (optional): { "target_user_id": "uuid" }
//   Omit to remove yourself. Supply to remove another member (admin-only, future V2).
//   V1: only self-removal is supported.

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }

  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } }
  );

  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return new Response("Unauthorized", { status: 401 });
  }

  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // V1: self-removal only
  const targetUserId = user.id;

  // Find member record
  const { data: member, error: memberError } = await adminClient
    .from("members")
    .select("id, household_id")
    .eq("user_id", targetUserId)
    .maybeSingle();

  if (memberError || !member) {
    return new Response(JSON.stringify({ error: "Not a member of any household." }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Delete member row — RLS already enforces this is only possible for own row,
  // but we use admin client here so the Edge Function can act on behalf of any user.
  const { error: deleteMemberError } = await adminClient
    .from("members")
    .delete()
    .eq("id", member.id);

  if (deleteMemberError) {
    return new Response(JSON.stringify({ error: "Failed to remove from household." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Revoke all refresh tokens for the user so their session cannot be renewed.
  // Their current access token (JWT) remains valid until expiry (~1hr) —
  // the iOS app will hit a 401 on the next refresh and redirect to login.
  const { error: signOutError } = await adminClient.auth.admin.signOut(targetUserId, "global");
  if (signOutError) {
    // Non-fatal: member row is already deleted; log and continue.
    console.warn(`[leave-household] Failed to revoke sessions for ${targetUserId}:`, signOutError.message);
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
