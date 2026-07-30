import SwiftUI

struct SigningProgressView: View {
    let configuration: SigningConfiguration
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    @State private var progress = SigningProgress(
        currentStage: .preparing,
        completedUnits: 0,
        totalUnits: 12,
        currentComponent: nil,
        recentMessage: "Starting…",
        startedAt: Date()
    )
    @State private var error: SignFlowError?
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 24) {
            if let error {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                Text(error.title).font(.title3.bold())
                Text(error.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(error.suggestedResolution)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                Button("Back") { router.pop() }
                    .buttonStyle(.borderedProminent)
            } else {
                ProgressView(value: progress.fractionCompleted)
                    .padding(.horizontal, 40)
                Text(progress.currentStage.rawValue)
                    .font(.headline)
                Text(progress.recentMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let component = progress.currentComponent {
                    Text(component)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .navigationTitle("Signing")
        .navigationBarBackButtonHidden(error == nil)
        .toolbar {
            if error == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        task?.cancel()
                        router.pop()
                    }
                }
            }
        }
        .task {
            let t = Task { await run() }
            task = t
            await t.value
        }
    }

    private func run() async {
        do {
            let result = try await environment.signingOrchestrator.sign(configuration: configuration) { update in
                Task { @MainActor in
                    progress = update
                }
            }
            await MainActor.run {
                environment.rememberSigned(result)
                router.pop()
                router.navigate(to: .signingResult(result))
            }
        } catch is CancellationError {
            error = .userCancelled
        } catch let sf as SignFlowError {
            error = sf
        } catch {
            self.error = .signingFailed(detail: error.localizedDescription)
        }
    }
}
