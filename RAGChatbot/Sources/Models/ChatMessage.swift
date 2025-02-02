import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isUser: Bool
    
    init(id: UUID = UUID(), content: String, isUser: Bool) {
        self.id = id
        self.content = content
        self.timestamp = Date()
        self.isUser = isUser
    }
}