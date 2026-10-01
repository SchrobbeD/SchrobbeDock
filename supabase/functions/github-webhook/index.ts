import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-hub-signature-256, x-github-event",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Verifieert de HMAC SHA-256 handtekening van GitHub
async function verifySignature(secret: string, header: string | null, payload: string): Promise<boolean> {
  if (!secret) return true; // Als er lokaal geen secret is ingesteld, bypass verificatie
  if (!header || !header.startsWith("sha256=")) return false;

  const signature = header.slice(7);
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signed = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
  const hashArray = Array.from(new Uint8Array(signed));
  const expectedSignature = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

  return signature === expectedSignature;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const webhookSecret = Deno.env.get("GITHUB_WEBHOOK_SECRET") ?? "";

    const rawBody = await req.text();
    const signatureHeader = req.headers.get("x-hub-signature-256");
    const eventType = req.headers.get("x-github-event") ?? "";

    // 1. Verifieer handtekening indien secret is geconfigureerd
    if (webhookSecret) {
      const isValid = await verifySignature(webhookSecret, signatureHeader, rawBody);
      if (!isValid) {
        return new Response(JSON.stringify({ error: "Invalid signature" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // 2. Beantwoord GitHub Ping event (wordt verstuurd bij aanmaken webhook)
    if (eventType === "ping") {
      return new Response(JSON.stringify({ message: "pong", status: "ready" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (eventType !== "issues") {
      return new Response(
        JSON.stringify({ message: `Ignored event type: ${eventType}` }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const payload = JSON.parse(rawBody);
    const action = payload.action;
    const issue = payload.issue;
    const repo = payload.repository?.name;
    const owner = payload.repository?.owner?.login;

    if (!issue || !issue.number) {
      return new Response(JSON.stringify({ error: "Missing issue data" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const issueNumber = issue.number;
    console.log(`[GitHub Webhook] Ontvangen event: issues.${action} voor #${issueNumber} in ${owner}/${repo}`);

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // 3. Zoek het gekoppelde feedback rapport in de database
    const { data: reports, error: findError } = await adminClient
      .from("feedback_reports")
      .select("id, status, apps(github_repo_name, github_repo_owner)")
      .eq("github_issue_number", issueNumber);

    if (findError || !reports || reports.length === 0) {
      console.log(`[GitHub Webhook] Geen feedback rapport gevonden voor issue #${issueNumber}`);
      return new Response(
        JSON.stringify({ message: `No report found for issue #${issueNumber}` }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Filter eventueel op repo naam als er meerdere apps zijn
    const matchingReport = reports.find((r: any) => {
      const appRepo = r.apps?.github_repo_name || "SchrobbeDock";
      return appRepo.toLowerCase() === (repo ?? "schrobbedock").toLowerCase();
    }) ?? reports[0];

    const reportId = matchingReport.id;
    let newStatus: string | null = null;

    // 4. Bepaal de nieuwe status op basis van de GitHub actie
    if (action === "closed") {
      newStatus = "resolved";
    } else if (action === "reopened") {
      newStatus = "open";
    } else if (action === "labeled") {
      const labelName = payload.label?.name?.toLowerCase() ?? "";
      if (labelName === "in-progress" || labelName.includes("in progress") || labelName.includes("in-progress")) {
        newStatus = "in_progress";
      }
    } else if (action === "unlabeled") {
      const labelName = payload.label?.name?.toLowerCase() ?? "";
      if (labelName === "in-progress" || labelName.includes("in progress") || labelName.includes("in-progress")) {
        // Als issue nog steeds open is, terug naar 'open'
        if (issue.state === "open") {
          newStatus = "open";
        }
      }
    }

    if (!newStatus || newStatus === matchingReport.status) {
      return new Response(
        JSON.stringify({ message: "No status update required", current_status: matchingReport.status }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Update het feedback rapport in PostgreSQL
    const { error: updateError } = await adminClient
      .from("feedback_reports")
      .update({
        status: newStatus,
        updated_at: new Date().toISOString(),
      })
      .eq("id", reportId);

    if (updateError) {
      console.error("[GitHub Webhook] Fout bij bijwerken status:", updateError);
      return new Response(JSON.stringify({ error: "Failed to update report", details: updateError }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`[GitHub Webhook] Rapport ${reportId} (Issue #${issueNumber}) succesvol bijgewerkt naar: ${newStatus}`);

    return new Response(
      JSON.stringify({
        success: true,
        report_id: reportId,
        github_issue_number: issueNumber,
        old_status: matchingReport.status,
        new_status: newStatus,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[GitHub Webhook] Onverwachte fout:", message);
    return new Response(JSON.stringify({ error: "Internal Server Error", message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
