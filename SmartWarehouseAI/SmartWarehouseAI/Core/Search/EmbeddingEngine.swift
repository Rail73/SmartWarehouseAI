//
//  EmbeddingEngine.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import CoreML
import NaturalLanguage

/// Vector embedding engine using Apple's NLEmbedding
/// Provides semantic vector representations of text for similarity search
class EmbeddingEngine {
    private var embedding: NLEmbedding?
    private let language: NLLanguage = .english
    private let maxDimension: Int

    init(maxDimension: Int = 300) {
        self.maxDimension = maxDimension
        loadEmbedding()
    }

    // MARK: - Setup

    /// Load NLEmbedding model
    private func loadEmbedding() {
        // Try to load word embedding for English
        embedding = NLEmbedding.wordEmbedding(for: language)

        if embedding == nil {
            print("⚠️ Warning: NLEmbedding not available for \(language.rawValue). Vector search will be limited.")
        } else {
            print("✅ NLEmbedding loaded successfully. Dimension: \(embedding?.dimension ?? 0)")
        }
    }

    // MARK: - Generate Embeddings

    /// Generate vector embedding for text
    /// - Parameter text: Input text to embed
    /// - Returns: Vector of doubles (normalized)
    func embed(_ text: String) -> [Double]? {
        guard let embedding = embedding else {
            // Fallback: use simple TF-IDF-like embedding
            return fallbackEmbed(text)
        }

        // Clean and tokenize text
        let cleanedText = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Get word vectors and average them
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = cleanedText

        var vectors: [[Double]] = []

        tokenizer.enumerateTokens(in: cleanedText.startIndex..<cleanedText.endIndex) { range, _ in
            let word = String(cleanedText[range])

            if let vector = embedding.vector(for: word) {
                vectors.append(vector)
            }

            return true
        }

        guard !vectors.isEmpty else {
            return fallbackEmbed(text)
        }

        // Average pooling of word vectors
        let dimension = vectors[0].count
        var avgVector = [Double](repeating: 0.0, count: dimension)

        for vector in vectors {
            for i in 0..<dimension {
                avgVector[i] += vector[i]
            }
        }

        let count = Double(vectors.count)
        for i in 0..<dimension {
            avgVector[i] /= count
        }

        // Normalize vector (L2 normalization)
        return normalize(avgVector)
    }

    /// Embed multiple texts in batch
    func embedBatch(_ texts: [String]) -> [[Double]?] {
        return texts.map { embed($0) }
    }

    // MARK: - Similarity

    /// Calculate cosine similarity between two vectors
    /// - Returns: Similarity score 0.0 - 1.0 (higher is more similar)
    func cosineSimilarity(_ vec1: [Double], _ vec2: [Double]) -> Double {
        guard vec1.count == vec2.count else { return 0.0 }

        let dotProduct = zip(vec1, vec2).map(*).reduce(0, +)

        // Vectors are already normalized, so denominator is 1.0
        // Cosine similarity ranges from -1 to 1, map to 0 to 1
        return (dotProduct + 1.0) / 2.0
    }

    /// Find top-k most similar vectors
    func topSimilar(query: [Double], candidates: [[Double]], k: Int = 10) -> [(index: Int, score: Double)] {
        let similarities = candidates.enumerated().map { index, candidate in
            (index: index, score: cosineSimilarity(query, candidate))
        }

        return Array(similarities.sorted { $0.score > $1.score }.prefix(k))
    }

    // MARK: - Helpers

    /// L2 normalization of vector
    private func normalize(_ vector: [Double]) -> [Double] {
        let magnitude = sqrt(vector.map { $0 * $0 }.reduce(0, +))

        guard magnitude > 0 else { return vector }

        return vector.map { $0 / magnitude }
    }

    /// Fallback embedding using character n-grams (when NLEmbedding unavailable)
    private func fallbackEmbed(_ text: String) -> [Double] {
        let cleaned = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Use character trigrams as features
        var features = [String: Int]()
        let chars = Array(cleaned)

        // Unigrams
        for char in chars {
            let key = String(char)
            features[key, default: 0] += 1
        }

        // Bigrams
        for i in 0..<(chars.count - 1) {
            let key = String(chars[i...i+1])
            features[key, default: 0] += 1
        }

        // Trigrams
        for i in 0..<(chars.count - 2) {
            let key = String(chars[i...i+2])
            features[key, default: 0] += 1
        }

        // Hash features to fixed-size vector
        var vector = [Double](repeating: 0.0, count: min(maxDimension, 100))

        for (feature, count) in features {
            let hash = abs(feature.hashValue) % vector.count
            vector[hash] += Double(count)
        }

        return normalize(vector)
    }
}

// MARK: - Vector Extensions

extension Array where Element == Double {
    /// Check if vector is valid (non-empty, no NaN/Inf)
    var isValid: Bool {
        return !isEmpty && !contains { $0.isNaN || $0.isInfinite }
    }

    /// Convert to Data for storage
    func toData() -> Data {
        return withUnsafeBytes { Data($0) }
    }

    /// Create vector from Data
    static func fromData(_ data: Data) -> [Double]? {
        guard data.count % MemoryLayout<Double>.size == 0 else { return nil }

        let count = data.count / MemoryLayout<Double>.size
        var vector = [Double](repeating: 0, count: count)

        _ = vector.withUnsafeMutableBytes { data.copyBytes(to: $0) }

        return vector
    }
}
