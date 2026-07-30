import SwiftUI

enum DeveloperAccountPlan: String, CaseIterable {
    case free
    case paid

    var title: String {
        switch self {
        case .free: return "Free Apple ID"
        case .paid: return "Apple Developer Program"
        }
    }

    var subtitle: String {
        switch self {
        case .free: return "Xcode-managed signing · 7-day validity"
        case .paid: return "Developer Portal assets · up to 1-year validity"
        }
    }
}

struct OnboardingView: View {
    @AppStorage("developerAccountPlan") private var storedPlan = DeveloperAccountPlan.free.rawValue
    @State private var page = 0
    @State private var selectedPlan: DeveloperAccountPlan = .free
    @State private var acknowledged = false
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            SignFlowTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("SIGNFLOW")
                        .font(.caption.weight(.bold))
                        .tracking(2.5)
                    Spacer()
                    Text("\(page + 1) / 3")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                TabView(selection: $page) {
                    welcomePage.tag(0)
                    accountPage.tag(1)
                    privacyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? SignFlowTheme.accent : Color.secondary.opacity(0.2))
                            .frame(width: index == page ? 28 : 8, height: 8)
                            .animation(.snappy, value: page)
                    }
                }
                .padding(.bottom, 18)

                SignFlowPrimaryButton(
                    title: page == 2 ? "Enter SignFlow" : "Continue",
                    systemImage: page == 2 ? "arrow.right" : "chevron.right",
                    isDisabled: page == 2 && !acknowledged
                ) {
                    if page < 2 {
                        withAnimation(.snappy) { page += 1 }
                    } else {
                        storedPlan = selectedPlan.rawValue
                        onComplete()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Image(systemName: "signature")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 78, height: 78)
                .background(SignFlowTheme.accent, in: RoundedRectangle(cornerRadius: 24))

            VStack(alignment: .leading, spacing: 12) {
                Text("Your signing workspace.")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .tracking(-1.2)
                Text("Import, inspect, sign, verify, and export authorized iOS apps—with credentials kept on your device.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(28)
    }

    private var accountPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            SignFlowSectionHeader(
                title: "Choose your account",
                subtitle: "This changes setup guidance, not your privacy."
            )

            ForEach(DeveloperAccountPlan.allCases, id: \.self) { plan in
                Button {
                    withAnimation(.snappy) { selectedPlan = plan }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: plan == .paid ? "checkmark.seal" : "person.crop.circle")
                            .font(.title2)
                            .foregroundStyle(SignFlowTheme.accent)
                            .frame(width: 44, height: 44)
                            .background(SignFlowTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(plan.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(plan.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedPlan == plan ? SignFlowTheme.accent : .secondary)
                    }
                    .padding(18)
                    .background(SignFlowTheme.surface, in: RoundedRectangle(cornerRadius: SignFlowTheme.cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: SignFlowTheme.cornerRadius)
                            .stroke(selectedPlan == plan ? SignFlowTheme.accent : SignFlowTheme.border, lineWidth: selectedPlan == plan ? 2 : 1)
                    }
                }
                .buttonStyle(.plain)
            }

            Text("Apple does not expose a public on-device API for creating certificates or profiles. Free accounts use assets created by Xcode; paid accounts can also use Developer Portal assets.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(28)
    }

    private var privacyPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            SignFlowSectionHeader(
                title: "Private by design",
                subtitle: "Signing material stays under your control."
            )

            privacyRow("lock.shield", "Local signing", "IPAs and credentials are processed on this device.")
            privacyRow("key", "Keychain protected", "Imported identities are stored in the iOS Keychain.")
            privacyRow("icloud.slash", "No credential upload", "SignFlow never asks for or sends your Apple ID password.")

            Toggle(isOn: $acknowledged) {
                Text("I will only sign apps, certificates, profiles, and devices I own or am authorized to use.")
                    .font(.subheadline)
            }
            .tint(SignFlowTheme.accent)
            .padding(.top, 8)

            Spacer()
        }
        .padding(28)
    }

    private func privacyRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(SignFlowTheme.accent)
                .frame(width: 42, height: 42)
                .background(SignFlowTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
