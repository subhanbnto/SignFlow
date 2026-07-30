# Dependency Evaluation

## ZIPFoundation

| Criterion | Assessment |
|---|---|
| **Repository** | https://github.com/weichsel/ZIPFoundation |
| **Version** | 0.9.19 (pinned exact) |
| **License** | MIT |
| **Maintenance** | Actively maintained, regular releases |
| **Why needed** | Entry-level ZIP iteration for safe IPA extraction |
| **Isolation** | `Infrastructure/Archive/SafeZIPExtractor.swift` only |

## zsign / Zupersign (xtool-org)

| Criterion | Assessment |
|---|---|
| **Repository** | https://github.com/xtool-org/zsign (fork of zhlynn/zsign) |
| **Product** | `Zupersign` |
| **License** | MIT |
| **Why needed** | On-device Mach-O / app bundle code signing; Apple `codesign` is not available on iOS |
| **Isolation** | Called only from `Infrastructure/CodeSigning/ZSignCodeSigner.swift` |
| **Also pulls** | xtool-core (OpenSSL + SignerSupport), MIT |

## Apple Frameworks (No Third-Party)

Foundation, Security, CryptoKit, UniformTypeIdentifiers, OSLog, SwiftUI, UserNotifications
