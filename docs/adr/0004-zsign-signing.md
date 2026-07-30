# ADR 0004: On-Device Signing via zsign

## Status
Accepted

## Context
SignFlow must sign IPA contents on iOS. Apple’s `codesign` tool is not available on-device. A full custom Mach-O SuperBlob + CMS implementation would be large and error-prone.

## Decision
Use **xtool-org/zsign** (`Zupersign` product, MIT) for app-bundle signing. Isolate all calls in `ZSignCodeSigner`. Export certificate DER + private key PEM from Keychain only for the duration of signing.

## Consequences
- Signing works without a Mac companion for the cryptographic step
- Private keys must be exportable (`SecKeyCopyExternalRepresentation`); Secure Enclave–backed keys are not supported
- Installation remains a separate concern; this build exports the IPA and does not claim silent install success
- Dependency pulls OpenSSL via xtool-core — document in THIRD_PARTY_NOTICES
