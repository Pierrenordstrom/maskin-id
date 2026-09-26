// Edge Function: invite-user
//
// Bjuder in en användare via e-post och kopplar hen till en organisation.
// Anropas från frontend (Administration) med den inloggade administratörens JWT:
//   supabase.functions.invoke("invite-user", { body: { email, fullName, organizationId, isAdmin } })
//
// Deploy:  supabase functions deploy invite-user
// Kräver:  SUPABASE_URL, SUPABASE_ANON_KEY och SUPABASE_SERVICE_ROLE_KEY (sätts automatiskt av Supabase)
//          SITE_URL (valfri) – dit inbjudningslänken leder, t.ex. https://maskinid.example/mina-sidor
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

interface InviteBody {
  email?: string;
  fullName?: string;
  organizationId?: string;
  isAdmin?: boolean;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { code: "okant", message: "Använd POST." });

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 1. Vem anropar? Kontrollera med anroparens egen JWT.
  const authHeader = req.headers.get("Authorization") ?? "";
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: authHeader } } });
  const { data: me, error: meError } = await caller.rpc("my_profile");
  if (meError || !me) return reply(401, { code: "ej_inloggad", message: "Du behöver logga in." });
  if (!me.isAdmin) return reply(403, { code: "saknar_behorighet", message: "Bara administratörer kan bjuda in användare." });

  // 2. Validera inmatningen.
  let body: InviteBody;
  try {
    body = await req.json();
  } catch {
    return reply(400, { code: "ogiltig_inmatning", message: "Ogiltig begäran." });
  }
  const email = body.email?.trim().toLowerCase() ?? "";
  const fullName = body.fullName?.trim() ?? "";
  if (!/^\S+@\S+\.\S+$/.test(email)) return reply(400, { code: "ogiltig_inmatning", message: "Skriv en giltig e-postadress." });
  if (!fullName) return reply(400, { code: "ogiltig_inmatning", message: "Skriv användarens namn." });
  if (!body.organizationId) return reply(400, { code: "ogiltig_inmatning", message: "Välj en organisation." });

  // 3. Skapa/bjud in auth-användaren med service role.
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const redirectTo = Deno.env.get("SITE_URL") ?? undefined;
  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
    data: { full_name: fullName },
    redirectTo,
  });
  if (inviteError || !invited.user) {
    const exists = inviteError?.message?.toLowerCase().includes("already");
    return reply(exists ? 409 : 500, {
      code: exists ? "finns_redan" : "okant",
      message: exists ? `Det finns redan ett konto för ${email}.` : "Inbjudan kunde inte skickas. Försök igen.",
    });
  }

  // 4. Koppla profilen till organisationen (funktionen kontrollerar igen att anroparen är admin).
  const { data: profile, error: profileError } = await admin.rpc("admin_attach_profile", {
    p_invited_by: me.id,
    p_user_id: invited.user.id,
    p_email: email,
    p_full_name: fullName,
    p_organization_id: body.organizationId,
    p_is_admin: body.isAdmin === true,
  });
  if (profileError) {
    await admin.auth.admin.deleteUser(invited.user.id);
    return reply(400, { code: "ogiltig_inmatning", message: profileError.message });
  }
  return reply(200, profile);
});
