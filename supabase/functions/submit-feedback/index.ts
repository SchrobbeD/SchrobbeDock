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
      console.error("submit-feedback auth error:", userError, "URL:", supabaseUrl);
      return new Response(JSON.stringify({ error: "Unauthorized", details: userError?.message }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const {
      app_slug = "hub_admin",
      title,
      description,
      category = "bug",
      severity = "medium",
      environment_info = {},
      attachment_urls = [],
      stack_trace,
    } = body;

    if (!title || !description) {
      return new Response(JSON.stringify({ error: "Title and description are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Zoek de app op via slug
    const { data: appData, error: appError } = await adminClient
      .from("apps")
      .select("id, name, slug, github_repo_owner, github_repo_name")
      .eq("slug", app_slug)
      .maybeSingle();

    if (appError || !appData) {
      return new Response(JSON.stringify({ error: `App with slug '${app_slug}' not found` }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Sla het rapport op in public.feedback_reports
    const { data: report, error: reportError } = await adminClient
      .from("feedback_reports")
      .insert({
        user_id: user.id,
        app_id: appData.id,
        title,
        description,
        category,
        severity,
        environment_info,
        attachment_urls,
        stack_trace,
        status: "open",
      })
      .select()
      .single();

    if (reportError || !report) {
      return new Response(JSON.stringify({ error: "Failed to create feedback report", details: reportError }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. GitHub Issue Creatie (indien token en repo geconfigureerd zijn)
    let githubIssueUrl: string | null = null;
    let githubIssueNumber: number | null = null;

    const owner = appData.github_repo_owner || "SchrobbeD";
    const repo = appData.github_repo_name || "SchrobbeDock";

    if (githubToken && repo) {
      try {
        const envTable = `| Eigenschap | Waarde |
|---|---|
| **Applicatie** | ${appData.name} (\`${appData.slug}\`) |
| **Gebruiker** | ${user.email ?? user.id} |
| **Categorie** | ${category} |
| **Ernst** | ${severity} |
| **Besturingssysteem** | ${environment_info.os ?? "Onbekend"} |
| **Browser / App** | ${environment_info.browser ?? environment_info.platform ?? "Onbekend"} |
| **Schermresolutie** | ${environment_info.screen_resolution ?? "Onbekend"} |
| **Actieve Route** | \`${environment_info.route ?? "/"}\` |
| **App Versie** | \`${environment_info.app_version ?? "1.0.0"}\` |`;

        let attachmentsSection = "";
        if (attachment_urls && attachment_urls.length > 0) {
          attachmentsSection = `\n### Bijlagen & Screenshots\n` +
            attachment_urls.map((url: string, i: number) => `![Bijlage ${i + 1}](${url})`).join("\n\n");
        }

        let stackSection = "";
        if (stack_trace) {
          stackSection = `\n\n<details>\n<summary>Stacktrace & Foutdetails</summary>\n\n\`\`\`\n${stack_trace}\n\`\`\`\n</details>`;
        }

        const detailsSection = `\n\n<details>\n<summary>Volledige Systeeminformatie (JSON)</summary>\n\n\`\`\`json\n${JSON.stringify(environment_info, null, 2)}\n\`\`\`\n</details>`;

        const issueBody = `### Beschrijving\n${description}\n\n### Omgeving & Details\n${envTable}${attachmentsSection}${stackSection}${detailsSection}\n\n---\n*Rapport ID: \`${report.id}\` • Ingezonden via SchrobbeDock Feedback*`;

        const labels = [
          "feedback",
          category === "bug" ? "bug" : (category === "enhancement" ? "enhancement" : "question"),
          `severity:${severity}`,
          `app:${appData.slug}`,
        ];

        const ghRes = await fetch(`https://api.github.com/repos/${owner}/${repo}/issues`, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${githubToken}`,
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "SchrobbeDock-Feedback-Bot",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            title: `[${appData.name}] ${title}`,
            body: issueBody,
            labels: labels,
          }),
        });

        if (ghRes.ok) {
          const ghData = await ghRes.json();
          githubIssueUrl = ghData.html_url;
          githubIssueNumber = ghData.number;

          // Update report met GitHub issue link & nummer
          await adminClient
            .from("feedback_reports")
            .update({
              github_issue_url: githubIssueUrl,
              github_issue_number: githubIssueNumber,
            })
            .eq("id", report.id);
        } else {
          const errText = await ghRes.text();
          console.error("GitHub API error:", ghRes.status, errText);
        }
      } catch (ghErr) {
        console.error("Error creating GitHub issue:", ghErr);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        report_id: report.id,
        github_issue_url: githubIssueUrl,
        github_issue_number: githubIssueNumber,
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
