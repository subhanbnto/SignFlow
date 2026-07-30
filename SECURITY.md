# Security Policy

## Credential Handling

- Signing identities are stored exclusively in the iOS Keychain.
- P12 passwords are never persisted — they exist only in memory during import.
- Private keys are never logged, uploaded, or stored outside the Keychain.
- Temporary files are deleted after each operation (success, failure, or cancellation).
- Workspaces are excluded from iCloud backup.

## Archive Safety

- ZIP Slip path traversal attacks are rejected.
- Symbolic links in archives are rejected.
- Configurable limits protect against decompression bombs (entry count, total size, compression ratio, directory depth, single file size).
- All imported files are treated as untrusted.

## Reporting a Vulnerability

If you discover a security issue, please report it privately. Do not open a public issue containing exploit details.

## What SignFlow Does Not Do

- Upload credentials or signing identities to any server.
- Use stolen, leaked, or shared Apple certificates.
- Bypass Apple certificate revocation.
- Bypass provisioning profile restrictions.
- Distribute applications using Enterprise certificates publicly.
- Automatically install applications without user approval.
