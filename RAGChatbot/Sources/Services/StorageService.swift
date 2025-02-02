import Foundation
import CoreData
import NaturalLanguage

class StorageService {
    static let shared = StorageService()
    private let coreDataManager = CoreDataManager.shared
    private let embedding = NLEmbedding.wordEmbedding(for: .english)
    
    // Cache frequently accessed embeddings
    private var embeddingCache: NSCache<NSString, NSArray> = {
        let cache = NSCache<NSString, NSArray>()
        cache.countLimit = 1000 // Adjust based on memory constraints
        return cache
    }()
    
    private init() {}
    
    // MARK: - Message Operations
    
    func saveMessage(_ message: ChatMessage) {
        coreDataManager.performBackgroundTask { context in
            let cdMessage = CDChatMessage(context: context)
            cdMessage.id = message.id
            cdMessage.content = message.content
            cdMessage.isUser = message.isUser
            cdMessage.timestamp = message.timestamp
            
            // Generate and save embedding
            if let vector = self.computeEmbedding(for: message.content) {
                let embedding = CDVectorEmbedding(context: context)
                embedding.vector = try? JSONEncoder().encode(vector)
                embedding.message = cdMessage
                
                // Cache the embedding
                self.cacheEmbedding(vector, for: message.id.uuidString)
            }
            
            try? context.save()
        }
    }
    
    func saveMessages(_ messages: [ChatMessage]) {
        coreDataManager.performBackgroundTask { context in
            for message in messages {
                let cdMessage = CDChatMessage(context: context)
                cdMessage.id = message.id
                cdMessage.content = message.content
                cdMessage.isUser = message.isUser
                cdMessage.timestamp = message.timestamp
                
                if let vector = self.computeEmbedding(for: message.content) {
                    let embedding = CDVectorEmbedding(context: context)
                    embedding.vector = try? JSONEncoder().encode(vector)
                    embedding.message = cdMessage
                    self.cacheEmbedding(vector, for: message.id.uuidString)
                }
            }
            try? context.save()
        }
    }
    
    func fetchMessages(limit: Int = 50) -> [ChatMessage] {
        let cdMessages = coreDataManager.fetchMessages(limit: limit)
        return cdMessages.map { cdMessage in
            ChatMessage(
                id: cdMessage.id ?? UUID(),
                content: cdMessage.content ?? "",
                isUser: cdMessage.isUser
            )
        }
    }
    
    // MARK: - Vector Operations
    
    private func cacheEmbedding(_ vector: [Double], for key: String) {
        embeddingCache.setObject(vector as NSArray, forKey: key as NSString)
    }
    
    private func getCachedEmbedding(for key: String) -> [Double]? {
        return embeddingCache.object(forKey: key as NSString) as? [Double]
    }
    
    func computeEmbedding(for text: String) -> [Double]? {
        guard let embedding = embedding else { return nil }
        
        // Preprocess text
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(100) // Limit to prevent processing extremely long texts
        
        var vectors: [[Double]] = []
        
        // Get embeddings for each word
        for word in words {
            if let vector = embedding.vector(for: word) {
                vectors.append(vector)
            }
        }
        
        guard !vectors.isEmpty else { return nil }
        
        // Calculate weighted average of vectors
        let vectorLength = vectors[0].count
        var averageVector = Array(repeating: 0.0, count: vectorLength)
        
        for vector in vectors {
            for (index, value) in vector.enumerated() {
                averageVector[index] += value
            }
        }
        
        // Normalize the final vector
        let finalVector = averageVector.map { $0 / Double(vectors.count) }
        return VectorMath.normalize(finalVector)
    }
    
    // MARK: - Semantic Search
    
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
    
    func findSimilarMessagesByVector(_ vector: [Double], limit: Int = 5) -> [ChatMessage] {
        let cdMessages = coreDataManager.findSimilarMessages(to: vector, limit: limit)
        return cdMessages.map { cdMessage in
            ChatMessage(
                id: cdMessage.id ?? UUID(),
                content: cdMessage.content ?? "",
                isUser: cdMessage.isUser
            )
        }
    }
    
    // MARK: - Performance Optimization
    
    func precomputeEmbeddings(forMessagesMatching predicate: NSPredicate? = nil) {
        coreDataManager.performBackgroundTask { context in
            let request: NSFetchRequest<CDChatMessage> = CDChatMessage.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "vectorEmbedding == nil"),
                predicate
            ].compactMap { $0 })
            
            do {
                let messages = try context.fetch(request)
                for message in messages {
                    if let content = message.content,
                       let vector = self.computeEmbedding(for: content) {
                        let embedding = CDVectorEmbedding(context: context)
                        embedding.vector = try? JSONEncoder().encode(vector)
                        embedding.message = message
                        
                        if let id = message.id?.uuidString {
                            self.cacheEmbedding(vector, for: id)
                        }
                    }
                }
                try context.save()
            } catch {
                print("Error precomputing embeddings: \(error)")
            }
        }
    }
    
    func clearEmbeddingCache() {
        embeddingCache.removeAllObjects()
    }
}