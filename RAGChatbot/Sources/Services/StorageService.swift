import Foundation
import CoreData
import NaturalLanguage

class StorageService {
    static let shared = StorageService()
    private let coreDataManager = CoreDataManager.shared
    private let embedding = NLEmbedding.wordEmbedding(for: .english)
    
    private init() {}
    
    // MARK: - Message Operations
    
    func saveMessage(_ message: ChatMessage) {
        let cdMessage = coreDataManager.createChatMessage(content: message.content, isUser: message.isUser)
        
        // Generate and save embedding for the message
        if let vector = computeEmbedding(for: message.content) {
            _ = coreDataManager.createVectorEmbedding(vector: vector, for: cdMessage)
        }
        
        coreDataManager.saveContext()
    }
    
    func fetchMessages() -> [ChatMessage] {
        let cdMessages = coreDataManager.fetchAllMessages()
        return cdMessages.map { cdMessage in
            ChatMessage(
                id: cdMessage.id ?? UUID(),
                content: cdMessage.content ?? "",
                isUser: cdMessage.isUser
            )
        }
    }
    
    // MARK: - Vector Operations
    
    func computeEmbedding(for text: String) -> [Double]? {
        guard let embedding = embedding else { return nil }
        
        // Split text into words and compute average embedding
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var vectors: [[Double]] = []
        
        for word in words {
            if let vector = embedding.vector(for: word) {
                vectors.append(vector)
            }
        }
        
        // Calculate average vector
        guard !vectors.isEmpty else { return nil }
        let vectorLength = vectors[0].count
        var averageVector = Array(repeating: 0.0, count: vectorLength)
        
        for vector in vectors {
            for (index, value) in vector.enumerated() {
                averageVector[index] += value
            }
        }
        
        return averageVector.map { $0 / Double(vectors.count) }
    }
    
    func findSimilarMessages(to query: String, limit: Int = 5) -> [ChatMessage] {
        guard let queryVector = computeEmbedding(for: query) else { return [] }
        
        let cdMessages = coreDataManager.findSimilarMessages(to: queryVector, limit: limit)
        return cdMessages.map { cdMessage in
            ChatMessage(
                id: cdMessage.id ?? UUID(),
                content: cdMessage.content ?? "",
                isUser: cdMessage.isUser
            )
        }
    }
}