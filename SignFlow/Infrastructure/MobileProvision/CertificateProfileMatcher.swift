import Foundation

enum CertificateProfileMatcher {
    /// Returns identities whose certificate fingerprint appears in the profile.
    static func matchingIdentities(
        _ identities: [SigningIdentity],
        in profile: ProvisioningProfile
    ) -> [SigningIdentity] {
        let profileFingerprints = Set(profile.developerCertificateFingerprints.map { $0.lowercased() })
        return identities.filter { profileFingerprints.contains($0.fingerprintSHA256.lowercased()) }
    }

    /// Returns profiles that include the identity's certificate fingerprint.
    static func matchingProfiles(
        _ profiles: [ProvisioningProfile],
        for identity: SigningIdentity
    ) -> [ProvisioningProfile] {
        let fingerprint = identity.fingerprintSHA256.lowercased()
        return profiles.filter {
            $0.developerCertificateFingerprints.map { $0.lowercased() }.contains(fingerprint)
        }
    }

    static func fingerprintMatches(_ identity: SigningIdentity, profile: ProvisioningProfile) -> Bool {
        profile.developerCertificateFingerprints
            .map { $0.lowercased() }
            .contains(identity.fingerprintSHA256.lowercased())
    }
}
