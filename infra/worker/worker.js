// Cloudflare Worker: R2-backed CDN for rokkitpokkit casync chunks and images.
// Serves /casync/* and /images/* from an R2 bucket binding.
// Chunks are immutable and cached aggressively at the edge.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
  "Access-Control-Allow-Headers": "Range, Content-Type, Accept, Priority",
  "Access-Control-Expose-Headers": "Accept-Ranges, Content-Length, Content-Range, Content-Type, ETag, Last-Modified",
};

function corsResponse(status) {
  return new Response(null, { status, headers: { ...CORS_HEADERS, "Access-Control-Max-Age": "86400" } });
}

export default {
  async fetch(request, env, ctx) {
    const { pathname } = new URL(request.url);

    if (!pathname.startsWith("/casync/") && !pathname.startsWith("/images/")) {
      return new Response("Not Found", { status: 404 });
    }

    if (request.method === "OPTIONS") {
      return corsResponse(204);
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const isChunk = pathname.startsWith("/casync/default.castr/");
    const isRef = pathname.startsWith("/casync/refs/");
    const cacheControl = isChunk ? "public, max-age=31536000, immutable" : isRef ? "no-cache" : "public, max-age=3600";

    // Edge cache handles Range slicing automatically (returns 206 from
    // a cached full response when Content-Length is present).
    const cache = caches.default;
    if (!isRef && request.method === "GET") {
      const cached = await cache.match(request);
      if (cached) return cached;
    }

    const key = pathname.slice(1);

    if (request.method === "HEAD") {
      const head = await env.BUCKET.head(key);
      if (!head) {
        return new Response("Not Found", { status: 404, headers: CORS_HEADERS });
      }

      const headers = new Headers();
      head.writeHttpMetadata(headers);
      headers.set("etag", head.httpEtag);
      headers.set("Cache-Control", cacheControl);
      headers.set("Access-Control-Allow-Origin", "*");
      headers.set("Access-Control-Expose-Headers", CORS_HEADERS["Access-Control-Expose-Headers"]);
      return new Response(null, { status: 200, headers });
    }

    // GET — fetch full object from R2 (range requests are served from
    // edge cache above; this path only runs on cache miss).
    const object = await env.BUCKET.get(key);

    if (!object) {
      return new Response("Not Found", { status: 404, headers: CORS_HEADERS });
    }

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set("etag", object.httpEtag);
    headers.set("Cache-Control", cacheControl);
    headers.set("Access-Control-Allow-Origin", "*");
    headers.set("Access-Control-Expose-Headers", CORS_HEADERS["Access-Control-Expose-Headers"]);

    const response = new Response(object.body, { status: 200, headers });

    // Store full response; edge cache will slice it for future Range requests.
    if (!isRef) {
      ctx.waitUntil(cache.put(request, response.clone()));
    }

    return response;
  },
};
