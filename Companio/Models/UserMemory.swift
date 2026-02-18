import Foundation

// MARK: - ConversationTurn

/// A single exchange in the conversation history.
struct ConversationTurn: Codable, Identifiable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }

    enum Role: String, Codable {
        case user
        case assistant
    }
}

// MARK: - UserMemory

/// Short-term conversation memory buffer.
/// Stores the last N conversation turns and persists them locally.
struct UserMemory: Codable {
    private(set) var turns: [ConversationTurn] = []
    var maxTurns: Int = 10

    // MARK: - Mutation

    mutating func addTurn(role: ConversationTurn.Role, content: String) {
        let turn = ConversationTurn(role: role, content: content)
        turns.append(turn)
        if turns.count > maxTurns {
            turns.removeFirst(turns.count - maxTurns)
        }
    }

    mutating func clear() {
        turns.removeAll()
    }

    // MARK: - LLM Context

    /// Formats memory as an array of message dicts for LLM injection.
    func asLLMMessages() -> [[String: String]] {
        turns.map { ["role": $0.role.rawValue, "content": $0.content] }
    }

    /// A compact string summary of recent context (for debugging / logging).
    var contextSummary: String {
        turns.suffix(4).map { "[\($0.role.rawValue)] \($0.content)" }.joined(separator: "\n")
    }

    // MARK: - Persistence

    static let userDefaultsKey = "companio.userMemory"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: UserMemory.userDefaultsKey)
        }
    }

    static func load() -> UserMemory {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let memory = try? JSONDecoder().decode(UserMemory.self, from: data) else {
            return UserMemory()
        }
        return memory
    }
}
