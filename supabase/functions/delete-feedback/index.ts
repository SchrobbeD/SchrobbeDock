// @ts-nocheck
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Extraheert het storage object pad uit een Supabase public URL
function extractStoragePath(url: string, bucketName = "feedback_attachments"): string | null {
  try {
    const marker = `/${bucketName}/`;
    const idx = url.indexOf(marker);
    if (idx !== -1) {
      const pathWithQuery = url.substring(idx + marker.length);
      return decodeURIComponent(pathWithQuery.split("?")[0]);
    }
  } catch (err) {
    console.error("Fout bij parsen van storage URL:", url, err);
  }
  return null;
}

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

    // 1. Verifieer de gebruiker
    const { data: { user }, error: userError } = await adminClient.auth.getUser(token);
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized", details: userError?.message }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Controleer of de gebruiker super_admin is op hub_admin
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

    const { report_id } = await req.json();
    if (!report_id) {
      return new Response(JSON.stringify({ error: "report_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Haal het feedback rapport op inclusief app GitHub repo gegevens
    const { data: report, error: fetchError } = await adminClient
      .from("feedback_reports")
      .select("id, github_issue_number, github_issue_url, attachment_urls, apps!inner(github_repo_owner, github_repo_name)")
      .eq("id", report_id)
      .maybeSingle();

    if (fetchError || !report) {
      return new Response(JSON.stringify({ error: "Feedback report not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const issueNumber = report.github_issue_number;
    const appData = (report as any).apps;
    const owner = appData?.github_repo_owner || "SchrobbeD";
    const repo = appData?.github_repo_name || "SchrobbeDock";

    // 4. Verwijder issue op GitHub indien gekoppeld (Strict Sync - Keuze 1.A)
    // NB: GitHub REST API ondersteunt géén DELETE van issues; dit kan uitsluitend via GraphQL deleteIssue!
    if (issueNumber && githubToken && repo) {
      console.log(`[delete-feedback] Ophalen van node_id voor GitHub issue #${issueNumber} op ${owner}/${repo}`);

      const issueRes = await fetch(`https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}`, {
        headers: {
          "Authorization": `Bearer ${githubToken}`,
          "Accept": "application/vnd.github+json",
          "User-Agent": "SchrobbeDock-Feedback-Bot",
        },
      });

      if (!issueRes.ok && issueRes.status !== 404) {
        const fetchErr = await issueRes.text();
        console.error(`[delete-feedback] Kon issue #${issueNumber} niet ophalen op GitHub (${issueRes.status}):`, fetchErr);
        return new Response(
          JSON.stringify({
            error: `GitHub weigert toegang tot issue #${issueNumber} (HTTP ${issueRes.status})`,
            details: fetchErr,
          }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (issueRes.ok) {
        const issueData = await issueRes.json();
        const nodeId = issueData.node_id;

        if (nodeId) {
          console.log(`[delete-feedback] Verwijderen issue #${issueNumber} via GitHub GraphQL (node_id: ${nodeId})...`);
          const gqlRes = await fetch("https://api.github.com/graphql", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${githubToken}`,
              "Content-Type": "application/json",
              "User-Agent": "SchrobbeDock-Feedback-Bot",
            },
            body: JSON.stringify({
              query: `mutation DeleteIssue($id: ID!) { deleteIssue(input: { issueId: $id }) { clientMutationId } }`,
              variables: { id: nodeId },
            }),
          });

          const gqlData = await gqlRes.json();
          if (gqlData.errors && gqlData.errors.length > 0) {
            const errorMsg = gqlData.errors.map((e: any) => e.message).join(", ");
            console.error(`[delete-feedback] GitHub GraphQL deleteIssue weigerde:`, errorMsg);
            return new Response(
              JSON.stringify({
                error: `GitHub weigert verwijdering van issue #${issueNumber}: ${errorMsg}`,
                graphql_errors: gqlData.errors,
              }),
              { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          }
          console.log(`[delete-feedback] GitHub issue #${issueNumber} succesvol verwijderd via GraphQL!`);
        }
      } else {
        console.log(`[delete-feedback] Issue #${issueNumber} bestaat niet meer op GitHub (404), doorgaan met lokale opschoning.`);
      }
    }

    // 5. Verwijder fysieke bijlagen uit Supabase Storage
    const attachmentUrls: string[] = report.attachment_urls || [];
    if (attachmentUrls.length > 0) {
      const pathsToDelete: string[] = [];
      for (const url of attachmentUrls) {
        const path = extractStoragePath(url, "feedback_attachments");
        if (path) {
          pathsToDelete.push(path);
        }
      }

      if (pathsToDelete.length > 0) {
        console.log(`[delete-feedback] Verwijderen ${pathsToDelete.length} bestanden uit storage bucket:`, pathsToDelete);
        const { error: storageError } = await adminClient.storage
          .from("feedback_attachments")
          .remove(pathsToDelete);

        if (storageError) {
          console.warn("[delete-feedback] Waarschuwing bij verwijderen storage bestanden:", storageError);
        }
      }
    }

    // 6. Verwijder het record uit public.feedback_reports
    const { error: deleteError } = await adminClient
      .from("feedback_reports")
      .delete()
      .eq("id", report_id);

    if (deleteError) {
      console.error("[delete-feedback] Fout bij verwijderen database record:", deleteError);
      return new Response(
        JSON.stringify({ error: "Fout bij verwijderen van feedback record in database", details: deleteError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[delete-feedback] Melding ${report_id} en GitHub issue #${issueNumber ?? '-'} succesvol verwijderd.`);
    return new Response(
      JSON.stringify({
        success: true,
        message: "Melding en gekoppeld GitHub issue succesvol verwijderd.",
        report_id,
        github_issue_number: issueNumber,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[delete-feedback] Onverwachte fout:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Interne serverfout" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
