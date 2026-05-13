// Cloudflare Worker: R2-backed CDN for rokkitpokkit artifacts.
// Serves /casync/*, /images/*, and /channels/* from an R2 bucket binding.
// Chunks are immutable and cached aggressively at the edge.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
  "Access-Control-Allow-Headers": "Range, Content-Type, Accept, Priority",
  "Access-Control-Expose-Headers": "Accept-Ranges, Content-Length, Content-Range, Content-Type, ETag, Last-Modified",
};

function addCorsHeaders(headers) {
  headers.set("Access-Control-Allow-Origin", CORS_HEADERS["Access-Control-Allow-Origin"]);
  headers.set("Access-Control-Expose-Headers", CORS_HEADERS["Access-Control-Expose-Headers"]);
}

function corsResponse(status) {
  return new Response(null, { status, headers: { ...CORS_HEADERS, "Access-Control-Max-Age": "86400" } });
}

function errorResponse(message, status, extraHeaders = {}) {
  const headers = new Headers(extraHeaders);
  addCorsHeaders(headers);
  return new Response(message, { status, headers });
}

function objectHeaders(object, cacheControl) {
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  headers.set("Cache-Control", cacheControl);
  headers.set("Accept-Ranges", "bytes");
  headers.set("Content-Length", String(object.size));
  addCorsHeaders(headers);
  return headers;
}

function parseRange(rangeHeader, size) {
  if (!rangeHeader) return null;

  const match = /^bytes=(\d*)-(\d*)$/.exec(rangeHeader.trim());
  if (!match || (match[1] === "" && match[2] === "")) return null;

  if (size === 0) return { unsatisfiable: true };

  let start;
  let end;

  if (match[1] === "") {
    const suffixLength = Number(match[2]);
    if (!Number.isSafeInteger(suffixLength) || suffixLength <= 0) return { unsatisfiable: true };

    start = Math.max(size - suffixLength, 0);
    end = size - 1;
  } else {
    start = Number(match[1]);
    end = match[2] === "" ? size - 1 : Number(match[2]);

    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end)) return null;
    if (start > end || start >= size) return { unsatisfiable: true };

    end = Math.min(end, size - 1);
  }

  return { start, end, length: end - start + 1 };
}

function rangeHeaders(object, cacheControl, range) {
  const headers = objectHeaders(object, cacheControl);
  headers.set("Content-Range", `bytes ${range.start}-${range.end}/${object.size}`);
  headers.set("Content-Length", String(range.length));
  return headers;
}

function unsatisfiableRangeResponse(size) {
  return errorResponse("Range Not Satisfiable", 416, {
    "Accept-Ranges": "bytes",
    "Content-Range": `bytes */${size}`,
  });
}

function hasSupportedRangeSyntax(rangeHeader) {
  if (!rangeHeader) return false;

  const match = /^bytes=(\d*)-(\d*)$/.exec(rangeHeader.trim());
  return Boolean(match && (match[1] !== "" || match[2] !== ""));
}

function isUsableCacheHit(response, needsRange) {
  return response && (!needsRange || response.status === 206);
}

export default {
  async fetch(request, env, ctx) {
    const { pathname } = new URL(request.url);

    if (!pathname.startsWith("/casync/") && !pathname.startsWith("/images/") && !pathname.startsWith("/channels/")) {
      return errorResponse("Not Found", 404);
    }

    if (request.method === "OPTIONS") {
      return corsResponse(204);
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      return errorResponse("Method Not Allowed", 405);
    }

    const isChunk = pathname.startsWith("/casync/default.castr/");
    const isRef = pathname.startsWith("/casync/refs/");
    const isChannel = pathname.startsWith("/channels/");
    const isCacheable = !isRef && !isChannel;
    const cacheControl = isChunk ? "public, max-age=31536000, immutable" : (isRef || isChannel) ? "no-cache" : "public, max-age=3600";
    const rangeHeader = request.headers.get("Range");
    const needsRange = hasSupportedRangeSyntax(rangeHeader);

    // Edge cache handles Range slicing automatically when a full response
    // with Content-Length is present.
    const cache = caches.default;
    const cacheKey = new Request(request.url, { method: "GET" });
    if (isCacheable && request.method === "GET") {
      const cached = await cache.match(request);
      if (isUsableCacheHit(cached, needsRange)) return cached;
    }

    const key = pathname.slice(1);

    if (request.method === "HEAD") {
      const head = await env.BUCKET.head(key);
      if (!head) {
        return errorResponse("Not Found", 404);
      }

      const headers = objectHeaders(head, cacheControl);
      return new Response(null, { status: 200, headers });
    }

    if (rangeHeader) {
      const head = await env.BUCKET.head(key);
      if (!head) {
        return errorResponse("Not Found", 404);
      }

      const range = parseRange(rangeHeader, head.size);
      if (range?.unsatisfiable) {
        return unsatisfiableRangeResponse(head.size);
      }

      if (range) {
        if (isCacheable) {
          const object = await env.BUCKET.get(key);
          if (!object) {
            return errorResponse("Not Found", 404);
          }

          const response = new Response(object.body, { status: 200, headers: objectHeaders(object, cacheControl) });
          await cache.put(cacheKey, response);

          const cached = await cache.match(request);
          if (isUsableCacheHit(cached, needsRange)) return cached;
        }

        const object = await env.BUCKET.get(key, { range: { offset: range.start, length: range.length } });
        if (!object) {
          return errorResponse("Not Found", 404);
        }

        return new Response(object.body, { status: 206, headers: rangeHeaders(head, cacheControl, range) });
      }
    }

    // GET - fetch full object from R2. Range requests for cacheable paths
    // only reach here when the header is invalid and should be ignored.
    const object = await env.BUCKET.get(key);

    if (!object) {
      return errorResponse("Not Found", 404);
    }

    const response = new Response(object.body, { status: 200, headers: objectHeaders(object, cacheControl) });

    // Store full response; edge cache will slice it for future Range requests.
    if (isCacheable) {
      ctx.waitUntil(cache.put(cacheKey, response.clone()));
    }

    return response;
  },
};
