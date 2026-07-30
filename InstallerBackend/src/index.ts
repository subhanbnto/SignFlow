import { jsonError, requireAPIToken } from "./auth";
import { buildOTAManifest, itmsServicesURL } from "./manifest";
import {
  cleanupExpiredReleases,
  deleteRelease,
  ipaKey,
  isExpired,
  parseMaxIPABytes,
  parseRetentionHours,
  partKey,
  randomToken,
  readMetadata,
  type ReleaseMetadata,
  writeMetadata,
} from "./release";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type, Content-Length",
  "Access-Control-Max-Age": "86400",
};

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    try {
      const response = await route(request, env, ctx);
      return withCORS(response);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Internal server error.";
      return withCORS(jsonError(500, message));
    }
  },

  async scheduled(_controller: ScheduledController, env: Env, _ctx: ExecutionContext): Promise<void> {
    await cleanupExpiredReleases(env.RELEASES);
  },
};

async function route(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  if (request.method === "GET" && path === "/health") {
    return Response.json({
      ok: true,
      service: "signflow-installer",
      retentionHours: parseRetentionHours(env),
      maxIPABytes: parseMaxIPABytes(env),
    });
  }

  if (request.method === "POST" && path === "/v1/releases") {
    const unauthorized = requireAPIToken(request, env);
    if (unauthorized) return unauthorized;
    return createRelease(request, env);
  }

  const partMatch = /^\/v1\/releases\/([^/]+)\/parts\/(\d+)$/.exec(path);
  if (request.method === "PUT" && partMatch) {
    const unauthorized = requireAPIToken(request, env);
    if (unauthorized) return unauthorized;
    return uploadPart(request, env, partMatch[1], Number.parseInt(partMatch[2], 10));
  }

  const completeMatch = /^\/v1\/releases\/([^/]+)\/complete$/.exec(path);
  if (request.method === "POST" && completeMatch) {
    const unauthorized = requireAPIToken(request, env);
    if (unauthorized) return unauthorized;
    return completeRelease(request, env, completeMatch[1]);
  }

  const deleteMatch = /^\/v1\/releases\/([^/]+)$/.exec(path);
  if (request.method === "DELETE" && deleteMatch) {
    const unauthorized = requireAPIToken(request, env);
    if (unauthorized) return unauthorized;
    await deleteRelease(env.RELEASES, deleteMatch[1]);
    return Response.json({ deleted: true });
  }

  const manifestMatch = /^\/v1\/d\/([^/]+)\/([^/]+)\/manifest\.plist$/.exec(path);
  if (request.method === "GET" && manifestMatch) {
    return serveManifest(request, env, manifestMatch[1], manifestMatch[2]);
  }

  const ipaMatch = /^\/v1\/d\/([^/]+)\/([^/]+)\/app\.ipa$/.exec(path);
  if ((request.method === "GET" || request.method === "HEAD") && ipaMatch) {
    return serveIPA(request, env, ipaMatch[1], ipaMatch[2], ctx);
  }

  return jsonError(404, "Not found.");
}

async function createRelease(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    bundleIdentifier?: string;
    bundleVersion?: string;
    title?: string;
    sha256?: string;
    byteSize?: number;
    partCount?: number;
  };

  const bundleIdentifier = body.bundleIdentifier?.trim() ?? "";
  const bundleVersion = body.bundleVersion?.trim() ?? "";
  const title = body.title?.trim() ?? "";
  const sha256 = body.sha256?.trim().toLowerCase() ?? "";
  const byteSize = body.byteSize ?? 0;
  const partCount = body.partCount ?? 0;
  const maxBytes = parseMaxIPABytes(env);

  if (!bundleIdentifier || !bundleVersion || !title) {
    return jsonError(400, "bundleIdentifier, bundleVersion, and title are required.");
  }
  if (!/^[a-f0-9]{64}$/.test(sha256)) {
    return jsonError(400, "sha256 must be a 64-character lowercase hex digest.");
  }
  if (!Number.isInteger(byteSize) || byteSize <= 0 || byteSize > maxBytes) {
    return jsonError(400, `byteSize must be between 1 and ${maxBytes}.`);
  }
  if (!Number.isInteger(partCount) || partCount < 1 || partCount > 512) {
    return jsonError(400, "partCount must be between 1 and 512.");
  }

  const releaseId = randomToken(16);
  const downloadToken = randomToken(24);
  const createdAt = new Date();
  const expiresAt = new Date(
    createdAt.getTime() + parseRetentionHours(env) * 60 * 60 * 1000
  );

  const metadata: ReleaseMetadata = {
    releaseId,
    downloadToken,
    bundleIdentifier,
    bundleVersion,
    title,
    sha256,
    byteSize,
    createdAt: createdAt.toISOString(),
    expiresAt: expiresAt.toISOString(),
    partCount,
    completed: false,
  };

  await writeMetadata(env.RELEASES, metadata);

  return Response.json(
    {
      releaseId,
      expiresAt: metadata.expiresAt,
      upload: {
        partCount,
        partURLTemplate: `/v1/releases/${releaseId}/parts/{partNumber}`,
        completeURL: `/v1/releases/${releaseId}/complete`,
      },
    },
    { status: 201 }
  );
}

async function uploadPart(
  request: Request,
  env: Env,
  releaseId: string,
  partNumber: number
): Promise<Response> {
  const metadata = await readMetadata(env.RELEASES, releaseId);
  if (!metadata) return jsonError(404, "Release not found.");
  if (isExpired(metadata)) {
    await deleteRelease(env.RELEASES, releaseId);
    return jsonError(410, "Release expired.");
  }
  if (metadata.completed) return jsonError(409, "Release already completed.");
  if (!Number.isInteger(partNumber) || partNumber < 1 || partNumber > metadata.partCount) {
    return jsonError(400, "Invalid part number.");
  }
  if (!request.body) return jsonError(400, "Empty part body.");

  const contentLength = Number.parseInt(request.headers.get("content-length") ?? "0", 10);
  if (!Number.isFinite(contentLength) || contentLength <= 0) {
    return jsonError(400, "Content-Length is required for part uploads.");
  }

  await env.RELEASES.put(partKey(releaseId, partNumber), request.body, {
    httpMetadata: { contentType: "application/octet-stream" },
  });

  return Response.json({ ok: true, partNumber });
}

async function completeRelease(
  request: Request,
  env: Env,
  releaseId: string
): Promise<Response> {
  const metadata = await readMetadata(env.RELEASES, releaseId);
  if (!metadata) return jsonError(404, "Release not found.");
  if (isExpired(metadata)) {
    await deleteRelease(env.RELEASES, releaseId);
    return jsonError(410, "Release expired.");
  }
  if (metadata.completed) {
    return finalizeResponse(request, metadata);
  }

  // Assemble via R2 multipart so large IPAs never fully load into Worker memory.
  const multipart = await env.RELEASES.createMultipartUpload(ipaKey(releaseId), {
    httpMetadata: { contentType: "application/octet-stream" },
  });

  const uploadedParts: R2UploadedPart[] = [];
  let totalBytes = 0;

  try {
    for (let partNumber = 1; partNumber <= metadata.partCount; partNumber += 1) {
      const part = await env.RELEASES.get(partKey(releaseId, partNumber));
      if (!part || !part.body) {
        await multipart.abort();
        return jsonError(400, `Missing upload part ${partNumber}.`);
      }
      totalBytes += part.size;
      const uploaded = await multipart.uploadPart(partNumber, part.body);
      uploadedParts.push(uploaded);
    }

    if (totalBytes !== metadata.byteSize) {
      await multipart.abort();
      return jsonError(
        400,
        `Uploaded size ${totalBytes} does not match expected ${metadata.byteSize}.`
      );
    }

    await multipart.complete(uploadedParts);
  } catch (error) {
    try {
      await multipart.abort();
    } catch {
      // ignore abort failures
    }
    throw error;
  }

  // Best-effort cleanup of temporary parts.
  await env.RELEASES.delete(
    Array.from({ length: metadata.partCount }, (_, index) => partKey(releaseId, index + 1))
  );

  const completed: ReleaseMetadata = {
    ...metadata,
    completed: true,
    receivedBytes: totalBytes,
  };
  await writeMetadata(env.RELEASES, completed);
  return finalizeResponse(request, completed);
}

function finalizeResponse(request: Request, metadata: ReleaseMetadata): Response {
  const origin = new URL(request.url).origin;
  const manifestURL = `${origin}/v1/d/${metadata.releaseId}/${metadata.downloadToken}/manifest.plist`;
  const ipaURL = `${origin}/v1/d/${metadata.releaseId}/${metadata.downloadToken}/app.ipa`;
  return Response.json({
    releaseId: metadata.releaseId,
    expiresAt: metadata.expiresAt,
    manifestURL,
    ipaURL,
    installURL: itmsServicesURL(manifestURL),
  });
}

async function serveManifest(
  request: Request,
  env: Env,
  releaseId: string,
  downloadToken: string
): Promise<Response> {
  const metadata = await authorizeDownload(env, releaseId, downloadToken);
  if (metadata instanceof Response) return metadata;

  const origin = new URL(request.url).origin;
  const ipaURL = `${origin}/v1/d/${metadata.releaseId}/${metadata.downloadToken}/app.ipa`;
  const plist = buildOTAManifest({
    ipaURL,
    bundleIdentifier: metadata.bundleIdentifier,
    bundleVersion: metadata.bundleVersion,
    title: metadata.title,
  });

  return new Response(plist, {
    headers: {
      "Content-Type": "application/xml",
      "Cache-Control": "no-store",
    },
  });
}

async function serveIPA(
  request: Request,
  env: Env,
  releaseId: string,
  downloadToken: string,
  ctx: ExecutionContext
): Promise<Response> {
  const metadata = await authorizeDownload(env, releaseId, downloadToken);
  if (metadata instanceof Response) return metadata;

  const range = parseRangeHeader(request.headers.get("range"), metadata.byteSize);
  if (range === "unsatisfiable") {
    return new Response(null, {
      status: 416,
      headers: { "Content-Range": `bytes */${metadata.byteSize}` },
    });
  }

  const object = await env.RELEASES.get(ipaKey(releaseId), range ? { range } : undefined);
  if (!object) {
    return jsonError(404, "IPA not found.");
  }

  const headers = new Headers();
  headers.set("Content-Type", "application/octet-stream");
  headers.set("Content-Disposition", 'attachment; filename="app.ipa"');
  headers.set("Cache-Control", "no-store");
  headers.set("ETag", object.httpEtag);
  // installd needs an exact length and resumable ranges to verify the downloaded package.
  headers.set("Accept-Ranges", "bytes");

  if (range) {
    const end = range.offset + range.length - 1;
    headers.set("Content-Range", `bytes ${range.offset}-${end}/${metadata.byteSize}`);
    headers.set("Content-Length", String(range.length));
  } else {
    headers.set("Content-Length", String(metadata.byteSize));
  }

  // Shorten retention once the package has been fetched; the cron job performs the delete
  // so an in-flight or resumed download is never truncated.
  ctx.waitUntil(scheduleTeardown(env, metadata));

  if (request.method === "HEAD") {
    return new Response(null, { status: range ? 206 : 200, headers });
  }

  return new Response(object.body ?? null, { status: range ? 206 : 200, headers });
}

const POST_DOWNLOAD_RETENTION_MS = 20 * 60 * 1000;

async function scheduleTeardown(env: Env, metadata: ReleaseMetadata): Promise<void> {
  const target = Date.now() + POST_DOWNLOAD_RETENTION_MS;
  if (new Date(metadata.expiresAt).getTime() <= target) return;
  await writeMetadata(env.RELEASES, {
    ...metadata,
    expiresAt: new Date(target).toISOString(),
  });
}

function parseRangeHeader(
  header: string | null,
  size: number
): { offset: number; length: number } | "unsatisfiable" | null {
  if (!header) return null;
  const match = /^bytes=(\d*)-(\d*)$/.exec(header.trim());
  if (!match) return null;

  const [, rawStart, rawEnd] = match;
  if (rawStart === "" && rawEnd === "") return null;

  let start: number;
  let end: number;
  if (rawStart === "") {
    const suffixLength = Number.parseInt(rawEnd, 10);
    if (!Number.isFinite(suffixLength) || suffixLength <= 0) return "unsatisfiable";
    start = Math.max(0, size - suffixLength);
    end = size - 1;
  } else {
    start = Number.parseInt(rawStart, 10);
    end = rawEnd === "" ? size - 1 : Number.parseInt(rawEnd, 10);
  }

  if (!Number.isFinite(start) || !Number.isFinite(end)) return "unsatisfiable";
  if (start > end || start >= size) return "unsatisfiable";
  end = Math.min(end, size - 1);

  return { offset: start, length: end - start + 1 };
}

async function authorizeDownload(
  env: Env,
  releaseId: string,
  downloadToken: string
): Promise<ReleaseMetadata | Response> {
  const metadata = await readMetadata(env.RELEASES, releaseId);
  if (!metadata || !metadata.completed) return jsonError(404, "Release not found.");
  if (metadata.downloadToken !== downloadToken) return jsonError(403, "Invalid download token.");
  if (isExpired(metadata)) {
    await deleteRelease(env.RELEASES, releaseId);
    return jsonError(410, "Release expired.");
  }
  return metadata;
}

function withCORS(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(CORS_HEADERS)) {
    headers.set(key, value);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}