# ADR 0002: Provisioning Profile Plist Extraction

## Status
Accepted

## Context
`.mobileprovision` files are CMS-signed property lists. On macOS, `CMSDecoder` APIs can unwrap the CMS envelope. Those APIs are not available to the iOS SDK used by this project.

## Decision
Extract the embedded plist by scanning for XML (`<?xml` … `</plist>`) or binary plist (`bplist00`) markers inside the CMS-wrapped file. This is a well-known, reliable approach for mobileprovision files.

## Consequences
- No dependency on macOS-only CMSDecoder
- Works for standard Apple-issued profiles
- Malformed profiles without a recognizable plist payload are rejected with `malformedProvisioningProfile`
