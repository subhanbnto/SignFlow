# Architecture

## Overview

SignFlow uses feature-oriented Clean Architecture with four primary layers:

```
Views (Features/) → Domain (Protocols/Models) ← Infrastructure (Implementations)
                         ↑
                   App (DI / Routing)
```

## Layers

### App
Entry point, dependency injection (`AppEnvironment`), routing (`AppRouter`), and the root view.

### Features
SwiftUI views and view-specific logic, organized by feature (Dashboard, ImportIPA, AppInspector, etc.). Features depend only on domain protocols and models — never on infrastructure types directly.

### Domain
- **Models:** Value types (`AppPackage`, `NestedBundle`, `ValidationIssue`, `ArchiveLimits`)
- **Protocols:** Service interfaces (`IPAImporting`, `IPAExtracting`, `IPAInspecting`, `TemporaryFileManaging`)
- **Errors:** Typed error system (`SignFlowError`)

### Infrastructure
Concrete implementations of domain protocols. Third-party library types (e.g., ZIPFoundation) are confined here and never leak into domain or feature layers.

Implemented services:
- **Archive:** IPA import, safe ZIP extraction, IPA inspection
- **Keychain:** P12 import (`PKCS12Parser` + `P12Importer`), `KeychainIdentityStore`, `InMemoryCertificateStore` (tests)
- **MobileProvision:** profile plist extraction, store, certificate/profile fingerprint matching
- **Cryptography:** SHA-256 hashing, certificate fingerprints, X.509 DER metadata extraction
- **Notifications:** local expiration warning scheduling abstraction

### Shared
Cross-cutting utilities, design system tokens, extensions, and logging helpers.

## Dependency Injection

All services are created in `AppEnvironment` and injected via SwiftUI's environment. This allows test doubles to be substituted easily.

## Concurrency

- `WorkspaceManager` is an `actor` to isolate mutable file-system state.
- Long operations use `Task.checkCancellation()` for cooperative cancellation.
- Types crossing concurrency boundaries conform to `Sendable`.

## Rules

1. Views must not call signing libraries or parse archives directly.
2. Features depend on domain protocols, not infrastructure.
3. Third-party types stay inside Infrastructure.
4. Avoid global mutable singletons.
5. Cleanup operations must be idempotent.
6. Use OSLog with privacy redaction for all logging.
