import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const arkApiKey = Deno.env.get("ARK_API_KEY");
    const arkBaseUrl = Deno.env.get("ARK_BASE_URL") || "https://ark.cn-beijing.volces.com/api/v3";

    if (!arkApiKey) {
      return new Response(JSON.stringify({ error: "ARK_API_KEY not configured" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();

    const arkResponse = await fetch(`${arkBaseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${arkApiKey}`,
      },
      body: JSON.stringify(body),
    });

    const data = await arkResponse.json();

    return new Response(JSON.stringify(data), {
      status: arkResponse.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
