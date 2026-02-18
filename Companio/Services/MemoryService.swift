import Foundation
import Combine

// MARK: - MemoryService

/// Manages the short-term conversation memory buffer.
/// Persists to UserDefaults and provides formatted context for LLM injection.
final class MemoryService: ObservableObject {

    // MARK: - Singleton
    static let shared = MemoryService()

    // MARK: - State
    @Published private(set) var memory: UserMemory

    // MARK: - Init
    private init() {
        self.memory = UserMemory.load()
    }

    // MARK: - Mutation

    func addUserMessage(_ text: String) {
        memory.addTurn(role: .user, content: text)
        memory.save()
    }

    func addAssistantMessage(_ text: String) {
        memory.addTurn(role: .assistant, content: text)
        memory.save()
    }

    func clearMemory() {
        memory.clear()
        memory.save()
    }

    // MARK: - LLM Context

    var currentMemory: UserMemory { memory }
}
