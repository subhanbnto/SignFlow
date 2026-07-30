# Credential Setup

SignFlow supports both free Apple IDs and paid Apple Developer Program accounts. Apple does not provide a public iOS API that lets a third-party app silently create signing certificates, register devices, or generate provisioning profiles. SignFlow therefore uses local assets the user creates through Apple-authorized tools.

## Free Apple ID

1. Add the Apple ID in Xcode.
2. Enable automatic signing for a personal-team test project.
3. Connect and select the target device, then build once.
4. In Keychain Access, export the Xcode-created development certificate and matching private key as a password-protected P12.
5. Import the Xcode-managed provisioning profile into SignFlow.

Free-account profiles typically expire after seven days and have Apple-imposed capability and App ID limits.

## Paid Developer Program

1. Create an Apple Development or Distribution certificate using Xcode or Certificates, IDs & Profiles.
2. Register authorized devices when using Development or Ad Hoc distribution.
3. Create a profile matching the target App ID, certificate, devices, and capabilities.
4. Export the certificate and private key as P12.
5. Import both assets into SignFlow.

## Security

- SignFlow never asks for or stores an Apple ID password.
- P12 passwords are used only during import.
- Signing identities are stored in the iOS Keychain.
- SignFlow does not bundle or distribute shared certificates.
- Certificate/profile compatibility is checked during preflight.
