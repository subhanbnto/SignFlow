import { describe, expect, it } from "vitest";
import { buildOTAManifest, itmsServicesURL } from "../src/manifest";
import { isExpired, type ReleaseMetadata } from "../src/release";

describe("buildOTAManifest", () => {
  it("embeds required Apple OTA keys and escapes XML", () => {
    const plist = buildOTAManifest({
      ipaURL: "https://example.com/app.ipa?x=1&y=2",
      bundleIdentifier: "com.example.app",
      bundleVersion: "1.2.3",
      title: "Demo <App> & Friends",
    });

    expect(plist).toContain("<key>kind</key>");
    expect(plist).toContain("<string>software-package</string>");
    expect(plist).toContain("<string>com.example.app</string>");
    expect(plist).toContain("<string>1.2.3</string>");
    expect(plist).toContain("<string>Demo &lt;App&gt; &amp; Friends</string>");
    expect(plist).toContain("https://example.com/app.ipa?x=1&amp;y=2");
  });
});

describe("itmsServicesURL", () => {
  it("URL-encodes the HTTPS manifest URL", () => {
    const url = itmsServicesURL("https://example.com/manifest.plist?token=abc");
    expect(url).toBe(
      "itms-services://?action=download-manifest&url=https%3A%2F%2Fexample.com%2Fmanifest.plist%3Ftoken%3Dabc"
    );
  });
});

describe("isExpired", () => {
  it("detects expired releases", () => {
    const metadata: ReleaseMetadata = {
      releaseId: "abc",
      downloadToken: "token",
      bundleIdentifier: "com.example.app",
      bundleVersion: "1",
      title: "Example",
      sha256: "a".repeat(64),
      byteSize: 10,
      createdAt: "2026-01-01T00:00:00.000Z",
      expiresAt: "2026-01-01T01:00:00.000Z",
      partCount: 1,
      completed: true,
    };

    expect(isExpired(metadata, new Date("2026-01-01T00:30:00.000Z"))).toBe(false);
    expect(isExpired(metadata, new Date("2026-01-01T02:00:00.000Z"))).toBe(true);
  });
});
