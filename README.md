# SignFlow

A privacy-focused iOS/iPadOS application for inspecting, signing, verifying, and exporting IPA files using certificates and provisioning profiles that the user owns or is authorized to use.

## Important

SignFlow is intended **only** for applications, certificates, provisioning profiles, and Apple devices that you own or are authorized to use. It does not support piracy, leaked certificates, certificate-revocation bypasses, or public Enterprise certificate distribution.

## Features (Current)

- Import and inspect IPA files securely
- Import P12 certificates into the Keychain (password never saved)
- Import and parse provisioning profiles
- Match certificates to profiles by fingerprint
- **Preflight validation** (cert/profile/App ID/team/entitlements/device rules)
- Preview bundle ID rewrites for the main app and extensions
- Entitlement strategies: Strict, Permitted Subset, Advanced Review
- **Sign, verify, and export** a signed IPA using zsign (on-device)
- **Hybrid installation**: Ad Hoc/Enterprise OTA via private Cloudflare Worker, or external installer handoff for free/development builds

## Requirements

- iOS 17.0+ / iPadOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Optional: Cloudflare account for the OTA installer backend (`InstallerBackend/`)

## Building

```bash
# Generate Xcode project (requires xcodegen)
xcodegen generate

# Build
xcodebuild -project SignFlow.xcodeproj -scheme SignFlow \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

# Test
xcodebuild -project SignFlow.xcodeproj -scheme SignFlowTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

## OTA Installer Backend

```bash
cd InstallerBackend
npm install --legacy-peer-deps
npx wrangler login
npx wrangler r2 bucket create signflow-releases
npx wrangler secret put API_TOKEN
npx wrangler deploy
```

Then paste the Worker URL and API token into **Settings → Installer Backend**.

## Architecture

SignFlow uses feature-oriented Clean Architecture with dependency injection. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

## License

See individual dependency licenses in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
