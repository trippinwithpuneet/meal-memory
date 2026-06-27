// Scheduled Edge Function — fires at 9pm in household timezone.
// Configure CRON in supabase/config.toml or via Dashboard → Edge Functions.
// CRON schedule: "0 21 * * *" (9pm UTC — adjust per household timezone at query time)

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const APNS_HOST = "https://api.push.apple.com";

serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!  // service role for cross-household read
  );

  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowStr = tomorrow.toISOString().split("T")[0];

  // Find all meal slots for tomorrow that have prep steps (hours_before > 0)
  const { data: slots, error } = await supabase
    .from("meal_slots")
    .select(`
      id,
      household_id,
      meal_type,
      recipes (
        name,
        emoji,
        steps
      )
    `)
    .eq("slot_date", tomorrowStr)
    .not("recipe_id", "is", null);

  if (error) {
    console.error("Failed to fetch slots:", error);
    return new Response("Error", { status: 500 });
  }

  const notifications: Array<{ householdId: string; title: string; body: string }> = [];

  for (const slot of slots ?? []) {
    const recipe = (slot as any).recipes;
    if (!recipe) continue;

    const steps: Array<{ text: string; hours_before: number }> = recipe.steps ?? [];
    const prepSteps = steps.filter((s) => s.hours_before > 0);
    if (prepSteps.length === 0) continue;

    const earliestPrepHours = Math.max(...prepSteps.map((s) => s.hours_before));
    notifications.push({
      householdId: slot.household_id,
      title: `${recipe.emoji} Prep reminder for tomorrow`,
      body: `${recipe.name} needs ${earliestPrepHours}h prep. ${prepSteps[0].text}`,
    });
  }

  // Fetch APNS tokens for each household and send
  let sent = 0;
  for (const notif of notifications) {
    const { data: members } = await supabase
      .from("members")
      .select("id, apns_device_tokens")
      .eq("household_id", notif.householdId);

    for (const member of members ?? []) {
      const tokens: string[] = member.apns_device_tokens ?? [];
      const staleTokens: string[] = [];

      for (const token of tokens) {
        const ok = await sendAPNS(token, notif.title, notif.body);
        if (ok) {
          sent++;
        } else {
          staleTokens.push(token);
        }
      }

      // Remove stale tokens (got a 410 from APNs)
      if (staleTokens.length > 0) {
        const freshTokens = tokens.filter((t) => !staleTokens.includes(t));
        await supabase
          .from("members")
          .update({ apns_device_tokens: freshTokens })
          .eq("id", member.id);
      }
    }
  }

  return new Response(JSON.stringify({ sent }), {
    headers: { "Content-Type": "application/json" },
  });
});

// ─── APNs sender ─────────────────────────────────────────────────────────────
async function sendAPNS(deviceToken: string, title: string, body: string): Promise<boolean> {
  const p8Key     = Deno.env.get("APNS_P8_KEY")!;
  const keyId     = Deno.env.get("APNS_KEY_ID")!;
  const teamId    = Deno.env.get("APNS_TEAM_ID")!;
  const bundleId  = Deno.env.get("APNS_BUNDLE_ID")!;

  const jwt = await buildAPNSJWT(p8Key, keyId, teamId);

  const payload = {
    aps: {
      alert: { title, body },
      sound: "default",
      badge: 1,
    },
  };

  const response = await fetch(`${APNS_HOST}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  // 410 = stale token, caller should remove it
  if (response.status === 410) {
    console.warn(`Stale APNS token: ${deviceToken.slice(0, 8)}…`);
  }

  return response.status === 200;
}

// ES256 JWT for APNs — built from the .p8 key stored as an Edge Function secret
async function buildAPNSJWT(p8Key: string, keyId: string, teamId: string): Promise<string> {
  const pem = p8Key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\n/g, "");
  const keyData = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const header  = btoa(JSON.stringify({ alg: "ES256", kid: keyId })).replace(/=/g, "");
  const payload = btoa(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) })).replace(/=/g, "");
  const sigInput = `${header}.${payload}`;

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(sigInput)
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature))).replace(/=/g, "");
  return `${sigInput}.${sigB64}`;
}
