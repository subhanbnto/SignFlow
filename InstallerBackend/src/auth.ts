export function requireAPIToken(request: Request, env: Env): Response | null {
  const expected = env.API_TOKEN;
  if (!expected) {
    return jsonError(500, "Server misconfigured: API_TOKEN secret is missing.");
  }

  const header = request.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  const provided = match?.[1]?.trim() ?? "";
  if (!provided || !timingSafe.equal(provided, expected)) {
    return jsonError(401, "Unauthorized.");
  }
  return null;
}

export function jsonError(status: number, message: string): Response {
  return Response.json({ error: message }, { status });
}

const timingSafe = {
  equal(a: string, b: string): boolean {
    const encoder = new TextEncoder();
    const left = encoder.encode(a);
    const right = encoder.encode(b);
    if (left.byteLength !== right.byteLength) {
      // Still walk the shorter buffer to avoid short-circuit timing leaks on length alone.
      let diff = left.byteLength ^ right.byteLength;
      const length = Math.min(left.byteLength, right.byteLength);
      for (let i = 0; i < length; i += 1) {
        diff |= left[i] ^ right[i];
      }
      return false;
    }
    let result = 0;
    for (let i = 0; i < left.byteLength; i += 1) {
      result |= left[i] ^ right[i];
    }
    return result === 0;
  },
};
