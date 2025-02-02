import Foundation

struct VectorMath {
    /// Computes cosine similarity between two vectors
    static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard normA > 0 && normB > 0 else { return 0.0 }
        return dotProduct / (normA * normB)
    }
    
    /// Calculate similarity scores between a query vector and a batch of vectors
    static func batchCosineSimilarity(query: [Double], vectors: [[Double]]) -> [(index: Int, similarity: Double)] {
        vectors.enumerated().map { (index, vector) in
            (index, cosineSimilarity(query, vector))
        }
    }
    
    /// Normalize a vector to unit length
    static func normalize(_ vector: [Double]) -> [Double] {
        let magnitude = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }
}