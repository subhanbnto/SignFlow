# Contributing to SignFlow

## Development Workflow

SignFlow is developed in milestones. Each milestone follows this process:

1. Inspect the current project state.
2. Plan changes and list affected files.
3. Implement the milestone.
4. Build and fix compiler errors.
5. Add tests.
6. Run tests and fix failures.
7. Update documentation.

## Rules

- **Never commit real certificates or private keys.** Test fixtures must use synthetic/generated credentials.
- **Never commit P12 files or provisioning profiles.**
- Run secret scanning before pushing.
- Follow the existing code style and architecture conventions.
- Add tests for all new domain and infrastructure code.
- Keep third-party types inside the Infrastructure layer.
- Use OSLog with privacy redaction for all logging.

## Code Style

- Swift, SwiftUI, Swift Concurrency
- `@Observable` over `ObservableObject` where possible
- Protocols in Domain, implementations in Infrastructure
- Dependency injection via `AppEnvironment`
