// DELETE /functions/v1/delete-account
// Deletes the calling user's account and all their data.
// App Store requires this flow to be available.
//
// Cascade behavior:
//   - Last member in household → deletes household (cascades to recipes, meal_slots)
//   - Not last member → deletes only their member row; household + data stays
//   - Always deletes auth.users record (invalidates all sessions immediately)

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

  // User-scoped client to identify the caller
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } }
  );

  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Admin client for privileged operations (delete auth user, invalidate sessions)
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Find the user's member record
  const { data: member, error: memberError } = await adminClient
    .from("members")
    .select("id, household_id")
    .eq("user_id", user.id)
    .maybeSingle();

  if (memberError) {
    return new Response(JSON.stringify({ error: "Failed to look up member record." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (member) {
    // Count remaining members in the household
    const { count } = await adminClient
      .from("members")
      .select("id", { count: "exact", head: true })
      .eq("household_id", member.household_id);

    if ((count ?? 0) <= 1) {
      // Last member — delete the whole household (cascades to all tables)
      const { error: deleteHouseholdError } = await adminClient
        .from("households")
        .delete()
        .eq("id", member.household_id);

      if (deleteHouseholdError) {
        return new Response(JSON.stringify({ error: "Failed to delete household." }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }
    } else {
      // Not the last member — delete only this member row
      const { error: deleteMemberError } = await adminClient
        .from("members")
        .delete()
        .eq("id", member.id);

      if (deleteMemberError) {
        return new Response(JSON.stringify({ error: "Failed to remove member." }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }
    }
  }

  // Delete the auth user — this immediately invalidates all sessions
  const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(user.id);
  if (deleteUserError) {
    return new Response(JSON.stringify({ error: "Failed to delete account." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
