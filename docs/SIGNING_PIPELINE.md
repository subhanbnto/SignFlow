# Signing Pipeline

## Status: Implemented (MVP)

Preflight validation (Milestone 3) and basic signing + export (Milestone 4) are implemented.

## Flow

1. Import IPA → inspect → stored under Documents/Imports
2. Import certificate (Keychain) + provisioning profile
3. Signing Setup → choose IPA, identity, profile, optional bundle ID / display name
4. Preflight → App ID, team, entitlements, device rules, expiry
5. Sign → extract → rewrite IDs → resolve entitlements → embed profile → zsign → verify → package → hash → cleanup
6. Result → share IPA; Install reports unavailable with an honest explanation

## Stages reported in UI

Preparing → Extracting → Inspecting → Resolving identifiers → Resolving entitlements → Embedding profiles / signing → Verifying → Packaging → Hashing → Cleaning
