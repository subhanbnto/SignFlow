# Threat Model

## Assets

1. User's signing identity (private key + certificate)
2. P12 password (transient, in-memory only)
3. Provisioning profiles
4. IPA contents and metadata
5. Temporary workspace files

## Threats and Mitigations

### Malicious IPA / ZIP Slip
**Threat:** A crafted IPA uses `../` path segments to write files outside the extraction directory.
**Mitigation:** `PathSanitizer` validates every entry path, rejecting traversal attempts. Resolved paths are checked against the workspace root.

### Decompression Bomb
**Threat:** A small archive expands to fill disk space.
**Mitigation:** `ArchiveLimits` enforces configurable maximums for compressed size, extracted size, entry count, single-file size, directory depth, and compression ratio.

### Unsafe Symbolic Links
**Threat:** Archive symlinks point outside the workspace.
**Mitigation:** All symbolic links in archives are rejected unconditionally.

### Certificate / Key Theft
**Threat:** Private keys extracted from Keychain or temporary files.
**Mitigation:** Identities stored in Keychain with device-only accessibility. P12 passwords never persisted. Temporary P12 files deleted immediately after import.

### Password Leakage
**Threat:** P12 password logged or persisted.
**Mitigation:** Passwords exist only as in-memory variables during import. OSLog uses privacy redaction. No password is written to disk, UserDefaults, or SwiftData.

### Temporary File Recovery
**Threat:** Workspace files remain on disk after operations.
**Mitigation:** Cleanup runs after success, failure, and cancellation. Orphaned workspaces are cleaned on app launch. Workspaces are excluded from iCloud backup.

### Sensitive Log Exposure
**Threat:** Logs contain private keys, passwords, or full certificate data.
**Mitigation:** OSLog privacy annotations redact sensitive values. A separate sanitized diagnostics exporter is planned.

### Malformed Info.plist / Mach-O
**Threat:** Crafted files cause crashes.
**Mitigation:** All parsing uses safe APIs (PropertyListSerialization, bounds-checked reads). No force unwraps in parsing paths.

### Dependency Supply Chain
**Threat:** Compromised third-party dependency.
**Mitigation:** Dependencies are version-pinned. Only ZIPFoundation (MIT, actively maintained) is used. License and maintenance status reviewed before inclusion.
