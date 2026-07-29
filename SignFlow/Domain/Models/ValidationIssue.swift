import Foundation

struct ValidationIssue: Identifiable, Hashable, Sendable {
    let id: UUID
    let severity: Severity
    let code: String
    let title: String
    let explanation: String
    let suggestedResolution: String?
    let affectedComponent: String?
    let affectedBundleIdentifier: String?

    init(
        severity: Severity,
        code: String,
        title: String,
        explanation: String,
        suggestedResolution: String? = nil,
        affectedComponent: String? = nil,
        affectedBundleIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.severity = severity
        self.code = code
        self.title = title
        self.explanation = explanation
        self.suggestedResolution = suggestedResolution
        self.affectedComponent = affectedComponent
        self.affectedBundleIdentifier = affectedBundleIdentifier
    }

    enum Severity: String, Sendable, Comparable {
        case info
        case warning
        case fatal

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            let order: [Severity] = [.info, .warning, .fatal]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }
}
