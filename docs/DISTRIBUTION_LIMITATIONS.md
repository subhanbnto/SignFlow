# Distribution Limitations

## Current State

SignFlow can inspect IPAs, manage certificates/profiles, run preflight validation, sign with a user-owned identity, verify structure, export a signed IPA, and optionally install through a **private Cloudflare OTA backend**.

## Installation Model

| Profile / Account | Install path |
|-------------------|--------------|
| Ad Hoc | HTTPS OTA via configured Cloudflare Worker (`itms-services`) on devices listed in the profile |
| Enterprise | HTTPS OTA via configured Cloudflare Worker after trusting the organization certificate |
| Development / Free Apple ID | External handoff (AltStore, SideStore, Xcode, Apple Configurator) |
| App Store | Not installable from SignFlow |

A sandboxed iOS app cannot silently install a local IPA. SignFlow does not claim silent installation and does not bypass Apple device registration or trust requirements.

## Hosted OTA Backend

The optional backend lives in `InstallerBackend/`:

1. Authenticated multipart IPA upload to private R2 storage
2. Tokenized HTTPS `manifest.plist` + IPA download
3. Short retention with automatic cleanup

Configure the Worker URL and API token in **Settings → Installer Backend**.

## Authorized Use Only

SignFlow is designed for:

- Applications you have developed or are authorized to modify
- Certificates you own or are authorized to use
- Provisioning profiles associated with your Apple Developer account
- Devices registered in your developer or organization account

## What SignFlow Will Not Support

- Leaked or stolen certificate distribution
- Certificate revocation bypasses
- Public Enterprise certificate distribution
- Silent installation without user approval
- Device registration bypasses
- Pirated application distribution
