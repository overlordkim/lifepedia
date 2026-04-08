import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const spiderKey = Deno.env.get("SPIDER_API_KEY");
    if (!spiderKey) {
      return new Response(
        JSON.stringify({ error: "SPIDER_API_KEY not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { url } = await req.json();
    if (!url) {
      return new Response(JSON.stringify({ error: "url is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const spiderResp = await fetch("https://api.spider.cloud/crawl", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${spiderKey}`,
      },
      body: JSON.stringify({
        url,
        limit: 1,
        return_format: "markdown",
      }),
    });

    if (!spiderResp.ok) {
      const errText = await spiderResp.text();
      return new Response(
        JSON.stringify({
          error: `Spider API ${spiderResp.status}`,
          detail: errText.slice(0, 500),
        }),
        {
          status: spiderResp.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const results = await spiderResp.json();
    const content =
      Array.isArray(results) && results.length > 0
        ? results[0].content || ""
        : typeof results === "object" && results.content
        ? results.content
        : JSON.stringify(results).slice(0, 5000);

    const truncated = content.slice(0, 8000);

    return new Response(
      JSON.stringify({
        url,
        content: truncated,
        length: content.length,
        truncated: content.length > 8000,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
