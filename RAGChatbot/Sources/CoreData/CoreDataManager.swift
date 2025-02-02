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
        embedding.vector = try? JSONEncoder().encode(vector)
        embedding.message = message
        return embedding
    }
    
    func getVector(from embedding: CDVectorEmbedding) -> [Double]? {
        guard let data = embedding.vector else { return nil }
        return try? JSONDecoder().decode([Double].self, from: data)
    }
    
    // MARK: - Search Operations
    
    func findSimilarMessages(to vector: [Double], limit: Int = 5) -> [CDChatMessage] {
        let request: NSFetchRequest<CDChatMessage> = CDChatMessage.fetchRequest()
        request.fetchLimit = limit
        
        // TODO: Implement vector similarity search
        // For now, return most recent messages
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDChatMessage.timestamp, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching similar messages: \(error)")
            return []
        }
    }
}