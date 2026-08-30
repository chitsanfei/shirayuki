import Foundation

@MainActor
final class AgentCommandLoopExecutor: AgentLoopCommandExecutor {
    private let service: AgentCommandService
    private let executionMode: () -> AgentExecutionMode

    init(
        service: AgentCommandService,
        executionMode: @escaping () -> AgentExecutionMode
    ) {
        self.service = service
        self.executionMode = executionMode
    }

    func execute(
        _ command: AgentCommand,
        sessionID: UUID,
        turnID: String,
        confirmed: Bool
    ) async -> AgentCommandExecution {
        let capability: AgentPageCapability?
        if command == .currentPageContent, confirmed {
            capability = service.issuePageCapability(sessionID: sessionID, turnID: turnID)
        } else {
            capability = nil
        }
        let result = await service.execute(
            command,
            sessionID: sessionID,
            capability: capability,
            confirmed: confirmed,
            turnID: turnID
        )
        if !confirmed,
           command != .currentPageContent,
           executionMode() == .yolo,
           case .requiresConfirmation = result {
            return await execute(
                command,
                sessionID: sessionID,
                turnID: turnID,
                confirmed: true
            )
        }
        switch result {
        case let .requiresConfirmation(preview):
            return .confirmation(preview)
        case .capabilityRequired:
            guard let preview = service.currentPageConfirmationPreview() else {
                return .observation("context_unavailable")
            }
            return .confirmation(preview)
        case let .pageContent(payload):
            return .observation("current_page_image_ready", transientImage: payload.jpegData)
        case .loginRequired:
            return .observation("login_required")
        case .configurationRequired:
            return .observation("configuration_required")
        case let .failure(.blockedWord(error)):
            return .observation(error.rawValue)
        case let .failure(error):
            return .observation(Self.code(for: error))
        default:
            return .observation(
                AgentResultProjector.project(result, for: command) ?? "capability_unavailable"
            )
        }
    }

    private static func code(for error: AgentCommandError) -> String {
        switch error {
        case .loginRequired: "login_required"
        case .contextUnavailable: "context_unavailable"
        case .capabilityRequired: "capability_required"
        case .configurationRequired: "configuration_required"
        case .invalidPage: "invalid_page"
        case .invalidIdentifier: "invalid_identifier"
        case .pageImageUnavailable: "page_image_unavailable"
        case .pageImageTooLarge: "page_image_too_large"
        case .pageImageRateLimited: "page_image_rate_limited"
        case .downloadConflict: "download_conflict"
        case .providerFailure: "provider_failure"
        case .riskAuthorizationRequired: "risk_authorization_required"
        case let .blockedWord(error): error.rawValue
        }
    }
}
