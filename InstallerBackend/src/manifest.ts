export interface ManifestInput {
  ipaURL: string;
  bundleIdentifier: string;
  bundleVersion: string;
  title: string;
}

function escapeXML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

/** Apple OTA installation manifest (XML plist). */
export function buildOTAManifest(input: ManifestInput): string {
  const bundleIdentifier = escapeXML(input.bundleIdentifier);
  const bundleVersion = escapeXML(input.bundleVersion);
  const title = escapeXML(input.title);
  const ipaURL = escapeXML(input.ipaURL);

  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>${ipaURL}</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>${bundleIdentifier}</string>
        <key>bundle-version</key>
        <string>${bundleVersion}</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>${title}</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
`;
}

export function itmsServicesURL(manifestHTTPSURL: string): string {
  return `itms-services://?action=download-manifest&url=${encodeURIComponent(manifestHTTPSURL)}`;
}
