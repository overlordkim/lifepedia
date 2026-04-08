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
    const seedreamModel = Deno.env.get("SEEDREAM_MODEL") || "doubao-seedream-5-0-260128";

    if (!arkApiKey) {
      return new Response(JSON.stringify({ error: "ARK_API_KEY not configured" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { prompt, size, section_title } = await req.json();

    if (!prompt) {
      return new Response(JSON.stringify({ error: "prompt is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const seedreamResponse = await fetch(`${arkBaseUrl}/images/generations`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${arkApiKey}`,
      },
      body: JSON.stringify({
        model: seedreamModel,
        prompt,
        size: size || "1024x1024",
        response_format: "url",
        watermark: false,
      }),
    });

    const data = await seedreamResponse.json();

    if (!seedreamResponse.ok) {
      return new Response(JSON.stringify({
        error: "Seedream API error",
        status: seedreamResponse.status,
        detail: data,
      }), {
        status: seedreamResponse.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const imageUrl = data?.data?.[0]?.url;

    return new Response(JSON.stringify({
      url: imageUrl,
      section_title: section_title || "",
      prompt,
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
