# ADR 0001: ZIP Extraction Library

## Status
Accepted

## Context
SignFlow needs to extract IPA files, which are ZIP archives. We need entry-level iteration to validate paths, check sizes, detect symlinks, and enforce extraction limits before writing files to disk.

Foundation's built-in `FileManager.unzipItem` and compression APIs do not provide per-entry metadata inspection before extraction.

## Decision
Use **ZIPFoundation** (MIT, v0.9.19) for ZIP extraction. Confine its usage to `Infrastructure/Archive/SafeZIPExtractor.swift` behind the `IPAExtracting` protocol.

## Alternatives Considered
- **minizip** — C library, harder to integrate via SPM, less Swift-idiomatic
- **libarchive** — Broader scope than needed, C-based
- **Manual ZIP parsing** — Error-prone, not worth the maintenance burden for a well-solved problem

## Consequences
- ZIPFoundation types never appear in domain models or features
- The dependency is version-pinned for reproducibility
- If ZIPFoundation becomes unmaintained, only `SafeZIPExtractor.swift` needs replacement
