# ADR 0003: Certificate Metadata via DER Parsing

## Status
Accepted

## Context
`SecCertificateCopyValues` and related OID property keys are macOS-only. SignFlow needs certificate subject, issuer, serial, and validity dates on iOS.

## Decision
Use `SecCertificateCopySubjectSummary` for a display name, and a minimal X.509 DER parser (`X509DERParser`) for serial number, issuer CN, subject CN/OU, and validity dates. Classify certificate type from the common-name string.

## Consequences
- No third-party ASN.1 dependency
- Parser covers the fields needed for SignFlow; exotic certificates may fall back to summary-only metadata
- Fingerprints always use CryptoKit SHA-256 over DER bytes
