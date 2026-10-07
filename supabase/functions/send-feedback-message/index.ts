// @ts-nocheck
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
      return new Response(JSON.stringify({ error: "Unauthorized", details: userError?.message }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { report_id, message, attachment_urls = [] } = await req.json();
    if (!report_id || !message || typeof message !== "string" || !message.trim()) {
      return new Response(JSON.stringify({ error: "report_id and message are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Haal feedback report op inclusief apps koppeling
    const { data: report, error: reportErr } = await adminClient
      .from("feedback_reports")
      .select("id, user_id, github_issue_number, apps(github_repo_owner, github_repo_name)")
      .eq("id", report_id)
      .single();

    if (reportErr || !report) {
      return new Response(JSON.stringify({ error: "Report not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Bepaal rol: Super Admin of Melder?
    let senderRole = "user";
    const { data: adminLicense } = await adminClient
      .from("user_licenses")
      .select("id, role, apps!inner(slug)")
      .eq("user_id", user.id)
      .eq("apps.slug", "hub_admin")
      .eq("role", "super_admin")
      .maybeSingle();

    if (adminLicense) {
      senderRole = "admin";
    } else if (report.user_id !== user.id) {
      return new Response(JSON.stringify({ error: "Forbidden: Je hebt geen toegang tot deze melding" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Haal profielnaam op voor weergave
    const { data: profile } = await adminClient
      .from("profiles")
      .select("first_name, last_name, email")
      .eq("id", user.id)
      .maybeSingle();

    let senderName = "Gebruiker";
    if (profile) {
      const fullName = [profile.first_name, profile.last_name].filter(Boolean).join(" ");
      senderName = fullName.trim() || (profile.email ? profile.email.split("@")[0] : "Gebruiker");
    }

    // 4. Synchroniseer met GitHub Issue indien aanwezig
    let githubCommentId = null;
    const appInfo = (report as any).apps;
    const owner = appInfo?.github_repo_owner || "SchrobbeD";
    const repo = appInfo?.github_repo_name || "SchrobbeDock";
    const issueNumber = report.github_issue_number;

    if (githubToken && issueNumber) {
      try {
        const roleLabel = senderRole === "admin" ? "Beheerder" : "Melder";
        let commentBody = `**[SchrobbeDock Hub - ${roleLabel}: ${senderName}]**\n\n${message.trim()}`;

        if (Array.isArray(attachment_urls) && attachment_urls.length > 0) {
          commentBody += "\n\n### Bijlagen\n";
          for (let i = 0; i < attachment_urls.length; i++) {
            commentBody += `![Bijlage ${i + 1}](${attachment_urls[i]})\n`;
          }
        }

        const ghRes = await fetch(
          `https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}/comments`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${githubToken}`,
              Accept: "application/vnd.github+json",
              "User-Agent": "SchrobbeDock-Feedback-Bot",
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ body: commentBody }),
          }
        );

        if (ghRes.ok) {
          const ghComment = await ghRes.json();
          githubCommentId = ghComment.id;
        } else {
          const ghErr = await ghRes.text();
          console.warn("[send-feedback-message] GitHub comment sync failed:", ghErr);
        }
      } catch (ghEx) {
        console.warn("[send-feedback-message] GitHub exception:", ghEx);
      }
    }

    // 5. Sla het bericht op in public.feedback_messages
    const { data: newMessage, error: insertErr } = await adminClient
      .from("feedback_messages")
      .insert({
        report_id: report_id,
        sender_id: user.id,
        sender_role: senderRole,
        sender_name: senderName,
        message: message.trim(),
        attachment_urls: attachment_urls,
        github_comment_id: githubCommentId,
      })
      .select()
      .single();

    if (insertErr) {
      return new Response(JSON.stringify({ error: "Failed to store message", details: insertErr }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true, message: newMessage }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("[send-feedback-message] Onverwachte fout:", err);
    return new Response(JSON.stringify({ error: err.message || "Interne serverfout" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
