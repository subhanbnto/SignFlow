import SwiftUI

enum SignFlowTheme {
    static let accent = Color.orange
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevatedSurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let border = Color.primary.opacity(0.08)
    static let cornerRadius: CGFloat = 20
    static let compactRadius: CGFloat = 14
}

struct SignFlowPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(SignFlowTheme.surface, in: RoundedRectangle(cornerRadius: SignFlowTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: SignFlowTheme.cornerRadius)
                    .stroke(SignFlowTheme.border, lineWidth: 1)
            }
    }
}

struct SignFlowPrimaryButton: View {
    let title: String
    let systemImage: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: SignFlowTheme.compactRadius))
        .tint(SignFlowTheme.accent)
        .disabled(isDisabled)
    }
}

struct SignFlowStatusBadge: View {
    enum Kind {
        case ready
        case warning
        case blocked
        case neutral

        var color: Color {
            switch self {
            case .ready: return .green
            case .warning: return .orange
            case .blocked: return .red
            case .neutral: return .secondary
            }
        }
    }

    let text: String
    let kind: Kind

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(kind.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(kind.color.opacity(0.12), in: Capsule())
    }
}

struct SignFlowSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SignFlowMetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .font(.subheadline)
    }
}

struct SignFlowEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(SignFlowTheme.accent)
                .frame(width: 68, height: 68)
                .background(SignFlowTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))

            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(SignFlowTheme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
