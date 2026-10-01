import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const githubToken = Deno.env.get("GITHUB_FEEDBACK_TOKEN") ?? "";

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace(/^Bearer\s+/i, "");
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    const { data: { user }, error: userError } = await adminClient.auth.getUser(token);
    if (userError || !user) {
      console.error("sync-feedback-status auth error:", userError, "URL:", supabaseUrl);
      return new Response(JSON.stringify({ error: "Unauthorized", details: userError?.message }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Controleer of de gebruiker super_admin is op hub_admin
    const { data: adminLicense } = await adminClient
      .from("user_licenses")
      .select("id, role, apps!inner(slug)")
      .eq("user_id", user.id)
      .eq("apps.slug", "hub_admin")
      .eq("role", "super_admin")
      .maybeSingle();

    if (!adminLicense) {
      return new Response(JSON.stringify({ error: "Forbidden: Super Admin access required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { report_id, new_status } = await req.json();
    if (!report_id || !new_status) {
      return new Response(JSON.stringify({ error: "report_id and new_status are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Haal het rapport op inclusief app GitHub routing
    const { data: report, error: reportFetchError } = await adminClient
      .from("feedback_reports")
      .select("id, status, github_issue_url, github_issue_number, apps(github_repo_owner, github_repo_name)")
      .eq("id", report_id)
      .single();

    if (reportFetchError || !report) {
      return new Response(JSON.stringify({ error: "Report not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Update status in de database
    const { data: updatedReport, error: updateError } = await adminClient
      .from("feedback_reports")
      .update({
        status: new_status,
        updated_at: new Date().toISOString(),
      })
      .eq("id", report_id)
      .select()
      .single();

    if (updateError) {
      return new Response(JSON.stringify({ error: "Failed to update report", details: updateError }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Synchroniseer met GitHub als er een gekoppeld issue is
    const appInfo = (report as any).apps;
    const owner = appInfo?.github_repo_owner || "SchrobbeD";
    const repo = appInfo?.github_repo_name || "SchrobbeDock";
    const issueNumber = report.github_issue_number;

    let githubSynced = false;

    if (githubToken && repo && issueNumber) {
      try {
        const ghHeaders = {
          "Authorization": `Bearer ${githubToken}`,
          "Accept": "application/vnd.github.v3+json",
          "User-Agent": "SchrobbeDock-Feedback-Bot",
          "Content-Type": "application/json",
        };

        if (new_status === "resolved" || new_status === "closed") {
          await fetch(`https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}`, {
            method: "PATCH",
            headers: ghHeaders,
            body: JSON.stringify({ state: "closed", state_reason: "completed" }),
          });

          // Verwijder in-progress label indien aanwezig
          await fetch(`https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}/labels/in-progress`, {
            method: "DELETE",
            headers: ghHeaders,
          }).catch(() => {});

          await fetch(`https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}/comments`, {
            method: "POST",
            headers: ghHeaders,
            body: JSON.stringify({
              body: `✅ **Melding gemarkeerd als ${new_status === "resolved" ? "Opgelost" : "Gesloten"}** via SchrobbeDock Hub Beheer.`,
            }),
          });
          githubSynced = true;
        } else if (new_status === "open") {
          await fetch(`https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}`, {
            method: "PATCH",
            headers: ghHeaders,
            body: JSON.stringify({ state: "open" }),
          });

          // Verwijder in-progress label indien aanwezig
          await fetch(`https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}/labels/in-progress`, {
            method: "DELETE",
            headers: ghHeaders,
          }).catch(() => {});

          await fetch(`https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}/comments`, {
            method: "POST",
            headers: ghHeaders,
            body: JSON.stringify({
              body: `🔄 **Melding heropend** via SchrobbeDock Hub Beheer.`,
            }),
          });
          githubSynced = true;
        } else if (new_status === "in_progress") {
          // Zorg dat het issue open is
          await fetch(`https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}`, {
            method: "PATCH",
            headers: ghHeaders,
            body: JSON.stringify({ state: "open" }),
          });

          // Voeg in-progress label toe
          await fetch(`https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}/labels`, {
            method: "POST",
            headers: ghHeaders,
            body: JSON.stringify({ labels: ["in-progress"] }),
          });

          await fetch(`https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}/comments`, {
            method: "POST",
            headers: ghHeaders,
            body: JSON.stringify({
              body: `⏳ **Status gewijzigd naar: In Behandeling** via SchrobbeDock Hub Beheer.`,
            }),
          });
          githubSynced = true;
        }
      } catch (ghErr) {
        console.error("Error syncing status to GitHub:", ghErr);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        report: updatedReport,
        github_synced: githubSynced,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: "Internal Server Error", message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
