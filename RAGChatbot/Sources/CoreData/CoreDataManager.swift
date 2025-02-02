import CoreData
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {
        setupPersistentContainer()
    }
    
    // MARK: - Core Data Setup
    
    private var persistentContainer: NSPersistentContainer!
    
    private func setupPersistentContainer() {
        persistentContainer = NSPersistentContainer(name: "RAGChatbot")
        
        // Optimize SQLite store for better performance
        let description = persistentContainer.persistentStoreDescriptor
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Enable SQLite performance optimizations
        let options = [
            // Enable WAL journal mode for better write performance
            NSSQLitePragmasOption: ["journal_mode": "WAL"],
            // Increase page size for better read performance
            NSSQLiteAnalyzeOption: true,
            // Enable automatic checkpointing
            "synchronous": "NORMAL"
        ]
        
        persistentContainer.persistentStoreDescriptor.setOption(options as NSObject, forKey: NSPersistentStoreOptionsKey)
        
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        
        // Enable automatic merging of changes
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Set up fetch batch size for better performance with large datasets
        persistentContainer.viewContext.persistentStoreCoordinator?.setQueryGenerationFrom(.current)
    }
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // MARK: - Context Management
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask { context in
            block(context)
        }
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let error = error as NSError
                print("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }
    }
    
    // MARK: - Optimized Chat Message Operations
    
    func createChatMessage(content: String, isUser: Bool) -> CDChatMessage {
        let message = CDChatMessage(context: viewContext)
        message.id = UUID()
        message.content = content
        message.isUser = isUser
        message.timestamp = Date()
        return message
    }
    
    func fetchMessages(limit: Int = 50, userOnly: Bool? = nil) -> [CDChatMessage] {
        let request: NSFetchRequest<CDChatMessage> = CDChatMessage.fetchRequest()
        
        // Set up predicates using indexed attributes
        var predicates: [NSPredicate] = []
        if let userOnly = userOnly {
            predicates.append(NSPredicate(format: "isUser == %@", NSNumber(value: userOnly)))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Use indexed timestamp for sorting
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDChatMessage.timestamp, ascending: false)]
        request.fetchLimit = limit
        
        // Enable batch fetching for better performance with relationships
        request.relationshipKeyPathsForPrefetching = ["vectorEmbedding"]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching messages: \(error)")
            return []
        }
    }
    
    // MARK: - Optimized Vector Operations
    
    func createVectorEmbedding(vector: [Double], for message: CDChatMessage) -> CDVectorEmbedding {
        let embedding = CDVectorEmbedding(context: viewContext)
        let normalizedVector = VectorMath.normalize(vector)
        embedding.vector = try? JSONEncoder().encode(normalizedVector)
        embedding.message = message
        return embedding
    }
    
    func findSimilarMessages(to queryVector: [Double], limit: Int = 5) -> [CDChatMessage] {
        let normalizedQuery = VectorMath.normalize(queryVector)
        
        // Use indexed fetch for messages with embeddings
        let request: NSFetchRequest<CDChatMessage> = CDChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "vectorEmbedding != nil")
        
        // Enable batch fetching for vector embeddings
        request.relationshipKeyPathsForPrefetching = ["vectorEmbedding"]
        
        do {
            // Fetch messages in batches for better memory management
            request.fetchBatchSize = 100
            let messages = try viewContext.fetch(request)
            
            // Process similarity scores in parallel for better performance
            let scoredMessages = DispatchQueue.concurrentPerform(iterations: messages.count) { index in
                let message = messages[index]
                guard let embedding = message.vectorEmbedding,
                      let vector = getVector(from: embedding) else {
                    return nil
                }
                
                let similarity = VectorMath.cosineSimilarity(normalizedQuery, vector)
                return ScoredMessage(message: message, similarity: similarity)
            }
            
            // Sort and return top results
            return scoredMessages
                .compactMap { $0 }
                .sorted { $0.similarity > $1.similarity }
                .prefix(limit)
                .map { $0.message }
            
        } catch {
            print("Error in similarity search: \(error)")
            return []
        }
    }
    
    func getVector(from embedding: CDVectorEmbedding) -> [Double]? {
        guard let data = embedding.vector else { return nil }
        return try? JSONDecoder().decode([Double].self, from: data)
    }
    
    // MARK: - Batch Operations
    
    func batchDeleteMessages(before date: Date) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CDChatMessage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "timestamp < %@", date as NSDate)
        
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDelete.resultType = .resultTypeObjectIDs
        
        do {
            let result = try persistentContainer.viewContext.execute(batchDelete) as? NSBatchDeleteResult
            let changes: [AnyHashable: Any] = [
                NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []
            ]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [persistentContainer.viewContext])
        } catch {
            print("Error performing batch delete: \(error)")
        }
    }
}

// MARK: - Helper Structures

extension CoreDataManager {
    struct ScoredMessage {
        let message: CDChatMessage
        let similarity: Double
    }
}