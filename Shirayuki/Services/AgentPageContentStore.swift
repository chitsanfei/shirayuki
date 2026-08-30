import Combine
import Foundation

/// Owns the bounded, currently visible page projection exposed to Agent currentContext.
@MainActor
final class AgentPageContentStore: ObservableObject {
    @Published private(set) var snapshot: AgentPageContentSnapshot = .unavailable
    private var ownerID: UUID?

    func publish(_ snapshot: AgentPageContentSnapshot, ownerID: UUID) {
        self.ownerID = ownerID
        self.snapshot = snapshot
    }

    func clear(ownerID: UUID) {
        guard self.ownerID == ownerID else { return }
        self.ownerID = nil
        snapshot = .unavailable
    }
}
