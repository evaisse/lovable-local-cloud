import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req: Request) => {
  const url = new URL(req.url);
  const pathParts = url.pathname.split("/").filter(Boolean);

  // Route to app functions or built-in smoke function
  const functionName = pathParts[0];

  if (functionName === "smoke") {
    return new Response(
      JSON.stringify({
        status: "ok",
        function: "smoke",
        timestamp: new Date().toISOString(),
      }),
      {
        headers: { "Content-Type": "application/json" },
      },
    );
  }

  // Try to import and run app function
  try {
    const handler = await import(
      `/home/deno/functions/app/${functionName}/index.ts`
    );
    return handler.default
      ? handler.default(req)
      : new Response("Function has no default export", { status: 500 });
  } catch (e) {
    // If function not found, return 404
    if (e instanceof Error && e.message.includes("Module not found")) {
      return new Response(
        JSON.stringify({ error: `Function '${functionName}' not found` }),
        {
          status: 404,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
