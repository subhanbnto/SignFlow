# ADR 0005: Hybrid Device Installation

## Status

Accepted

## Context

A sandboxed iOS app cannot install a local IPA through public Apple APIs. Users still expect a professional "Install" action after signing.

## Decision

Use a hybrid model:

1. **Ad Hoc / Enterprise**: temporary private HTTPS OTA via Cloudflare Worker + R2 and `itms-services`
2. **Development / Free**: system share sheet handoff to AltStore, SideStore, Xcode, or Apple Configurator
3. Never claim silent installation or bypass provisioning/trust requirements

## Consequences

- Requires an optional Cloudflare backend and short-lived IPA upload consent
- Ad Hoc installs still need the device UDID in the profile
- Free-account installs remain dependent on an external companion installer
