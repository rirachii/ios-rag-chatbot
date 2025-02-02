import CoreData
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "RAGChatbot")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let error = error as NSError
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }
    }
    
    // MARK: - Chat Message Operations
    
    func createChatMessage(content: String, isUser: Bool) -> CDChatMessage {
        let message = CDChatMessage(context: viewContext)
        message.id = UUID()
        message.content = content
        message.isUser = isUser
        message.timestamp = Date()
        return message
    }
    
    func fetchAllMessages() -> [CDChatMessage] {
        let request: NSFetchRequest<CDChatMessage> = CDChatMessage.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDChatMessage.timestamp, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching messages: \(error)")
            return []
        }
    }
    
    // MARK: - Vector Embedding Operations
    
    func createVectorEmbedding(vector: [Double], for message: CDChatMessage) -> CDVectorEmbedding {
        let embedding = CDVectorEmbedding(context: viewContext)
        // Normalize vector before storing
        let normalizedVector = VectorMath.normalize(vector)
        embedding.vector = try? JSONEncoder().encode(normalizedVector)
        embedding.message = message
        return embedding
    }
    
    func getVector(from embedding: CDVectorEmbedding) -> [Double]? {
        guard let data = embedding.vector else { return nil }
        return try? JSONDecoder().decode([Double].self, from: data)
    }
    
    // MARK: - Vector Similarity Search
    
    struct ScoredMessage {
        let message: CDChatMessage
        let similarity: Double
    }
    
    func findSimilarMessages(to queryVector: [Double], limit: Int = 5) -> [CDChatMessage] {
        // Normalize query vector
        let normalizedQuery = VectorMath.normalize(queryVector)
        
        // Fetch all messages with embeddings
        let request: NSFetchRequest<CDChatMessage> = CDChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "vectorEmbedding != nil")
        
        do {
            let messages = try viewContext.fetch(request)
            
            // Calculate similarity scores
            let scoredMessages: [ScoredMessage] = messages.compactMap { message in
                guard let embedding = message.vectorEmbedding,
                      let vector = getVector(from: embedding) else {
                    return nil
                }
                
                let similarity = VectorMath.cosineSimilarity(normalizedQuery, vector)
                return ScoredMessage(message: message, similarity: similarity)
            }
            
            // Sort by similarity and return top results
            return scoredMessages
                .sorted { $0.similarity > $1.similarity }
                .prefix(limit)
                .map { $0.message }
            
        } catch {
            print("Error fetching messages for similarity search: \(error)")
            return []
        }
    }
    
    // MARK: - Batch Operations
    
    func batchDeleteAllData() {
        let entityNames = ["CDChatMessage", "CDVectorEmbedding"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try viewContext.execute(batchDeleteRequest)
            } catch {
                print("Error batch deleting \(entityName): \(error)")
            }
        }
        
        saveContext()
    }
}