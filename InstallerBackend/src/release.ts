export interface ReleaseMetadata {
  releaseId: string;
  downloadToken: string;
  bundleIdentifier: string;
  bundleVersion: string;
  title: string;
  sha256: string;
  byteSize: number;
  createdAt: string;
  expiresAt: string;
  partCount: number;
  completed: boolean;
  receivedBytes?: number;
}

export function releasePrefix(releaseId: string): string {
  return `releases/${releaseId}`;
}

export function metadataKey(releaseId: string): string {
  return `${releasePrefix(releaseId)}/metadata.json`;
}

export function partKey(releaseId: string, partNumber: number): string {
  return `${releasePrefix(releaseId)}/parts/${String(partNumber).padStart(5, "0")}`;
}

export function ipaKey(releaseId: string): string {
  return `${releasePrefix(releaseId)}/app.ipa`;
}

export function randomToken(bytes = 24): string {
  const buffer = new Uint8Array(bytes);
  crypto.getRandomValues(buffer);
  return [...buffer].map((value) => value.toString(16).padStart(2, "0")).join("");
}

export function parseRetentionHours(env: Env): number {
  const parsed = Number.parseInt(env.RETENTION_HOURS || "6", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 6;
}

export function parseMaxIPABytes(env: Env): number {
  const parsed = Number.parseInt(env.MAX_IPA_BYTES || "524288000", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 524288000;
}

export function isExpired(metadata: ReleaseMetadata, now = new Date()): boolean {
  return new Date(metadata.expiresAt).getTime() <= now.getTime();
}

export async function readMetadata(
  bucket: R2Bucket,
  releaseId: string
): Promise<ReleaseMetadata | null> {
  const object = await bucket.get(metadataKey(releaseId));
  if (!object) return null;
  return (await object.json()) as ReleaseMetadata;
}

export async function writeMetadata(
  bucket: R2Bucket,
  metadata: ReleaseMetadata
): Promise<void> {
  await bucket.put(metadataKey(metadata.releaseId), JSON.stringify(metadata), {
    httpMetadata: { contentType: "application/json" },
  });
}

export async function deleteRelease(bucket: R2Bucket, releaseId: string): Promise<void> {
  let cursor: string | undefined;
  do {
    const listed = await bucket.list({ prefix: releasePrefix(releaseId), cursor });
    if (listed.objects.length > 0) {
      await bucket.delete(listed.objects.map((object) => object.key));
    }
    cursor = listed.truncated ? listed.cursor : undefined;
  } while (cursor);
}

export async function cleanupExpiredReleases(
  bucket: R2Bucket,
  now = new Date()
): Promise<number> {
  let deleted = 0;
  let cursor: string | undefined;
  do {
    const listed = await bucket.list({ prefix: "releases/", cursor });
    const metadataObjects = listed.objects.filter((object) =>
      object.key.endsWith("/metadata.json")
    );
    for (const object of metadataObjects) {
      const body = await bucket.get(object.key);
      if (!body) continue;
      const metadata = (await body.json()) as ReleaseMetadata;
      if (isExpired(metadata, now)) {
        await deleteRelease(bucket, metadata.releaseId);
        deleted += 1;
      }
    }
    cursor = listed.truncated ? listed.cursor : undefined;
  } while (cursor);
  return deleted;
}
