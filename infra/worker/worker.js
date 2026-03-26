// Cloudflare Worker: B2 S3 proxy with AWS Sig V4 signing for rokkitpokkit CDN.
// Serves /casync/* and /images/* from Backblaze B2 via S3-compatible API.
// Env bindings: B2_ENDPOINT, B2_BUCKET, B2_ACCESS_KEY_ID, B2_SECRET_ACCESS_KEY

const EMPTY_HASH = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
  "Access-Control-Allow-Headers": "Range, Content-Type, Accept, Priority",
  "Access-Control-Expose-Headers": "Accept-Ranges, Content-Length, Content-Range, Content-Type, ETag, Last-Modified",
};

function hexEncode(buf) {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(data) {
  const encoded = typeof data === "string" ? new TextEncoder().encode(data) : data;
  return hexEncode(await crypto.subtle.digest("SHA-256", encoded));
}

async function hmacSha256(key, message) {
  const keyData = typeof key === "string" ? new TextEncoder().encode(key) : key;
  const cryptoKey = await crypto.subtle.importKey("raw", keyData, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", cryptoKey, new TextEncoder().encode(message)));
}

async function signV4(method, url, headers, env) {
  const { hostname, pathname, searchParams } = new URL(url);
  const region = env.B2_ENDPOINT.replace(/^s3\./, "").replace(/\.backblazeb2\.com$/, "");

  const now = new Date();
  const dateStamp = now.toISOString().replace(/[-:]/g, "").slice(0, 8);
  const amzDate = dateStamp + "T" + now.toISOString().replace(/[-:]/g, "").slice(9, 15) + "Z";
  const scope = `${dateStamp}/${region}/s3/aws4_request`;

  headers["host"] = hostname;
  headers["x-amz-date"] = amzDate;
  headers["x-amz-content-sha256"] = EMPTY_HASH;

  const signedHeaderNames = Object.keys(headers).sort();
  const canonicalHeaders = signedHeaderNames.map((k) => `${k}:${headers[k]}\n`).join("");
  const signedHeadersStr = signedHeaderNames.join(";");

  const sortedParams = [...searchParams.entries()].sort().map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join("&");

  const canonicalRequest = [method, pathname, sortedParams, canonicalHeaders, signedHeadersStr, EMPTY_HASH].join("\n");
  const stringToSign = ["AWS4-HMAC-SHA256", amzDate, scope, await sha256Hex(canonicalRequest)].join("\n");

  let signingKey = await hmacSha256("AWS4" + env.B2_SECRET_ACCESS_KEY, dateStamp);
  signingKey = await hmacSha256(signingKey, region);
  signingKey = await hmacSha256(signingKey, "s3");
  signingKey = await hmacSha256(signingKey, "aws4_request");
  const signature = hexEncode(await crypto.subtle.sign("HMAC", await crypto.subtle.importKey("raw", signingKey, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]), new TextEncoder().encode(stringToSign)));

  headers["authorization"] = `AWS4-HMAC-SHA256 Credential=${env.B2_ACCESS_KEY_ID}/${scope}, SignedHeaders=${signedHeadersStr}, Signature=${signature}`;
  return headers;
}

function corsResponse(status) {
  return new Response(null, { status, headers: { ...CORS_HEADERS, "Access-Control-Max-Age": "86400" } });
}

export default {
  async fetch(request, env) {
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

    const objectKey = pathname.slice(1);
    const s3Url = `https://${env.B2_ENDPOINT}/${env.B2_BUCKET}/${objectKey}`;

    const headersToSign = {};
    const range = request.headers.get("range");
    if (range) {
      headersToSign["range"] = range;
    }

    await signV4(request.method, s3Url, headersToSign, env);

    const isChunk = pathname.startsWith("/casync/default.castr/");
    const isRef = pathname.startsWith("/casync/refs/");
    const cacheTtl = isChunk ? 31536000 : isRef ? 0 : 3600;

    const cfOpts = isRef ? {} : { cacheTtl, cacheEverything: true };
    const upstream = await fetch(s3Url, {
      method: request.method,
      headers: headersToSign,
      cf: cfOpts,
    });

    const resp = new Headers(upstream.headers);
    resp.set("Access-Control-Allow-Origin", "*");
    resp.set("Access-Control-Expose-Headers", CORS_HEADERS["Access-Control-Expose-Headers"]);
    const cacheControl = isChunk ? "public, max-age=31536000, immutable" : isRef ? "no-cache" : "public, max-age=3600";
    resp.set("Cache-Control", cacheControl);

    return new Response(upstream.body, { status: upstream.status, headers: resp });
  },
};
