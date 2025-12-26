import Foundation

/// Utility for splitting text into manageable chunks for LLM processing
enum TextChunker {

    /// Splits text into chunks at natural boundaries (sentences/paragraphs)
    /// - Parameters:
    ///   - text: The text to split
    ///   - maxChunkSize: Maximum size of each chunk in characters (default: 12000)
    /// - Returns: Array of text chunks
    static func split(_ text: String, maxChunkSize: Int = 12000) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""

        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))

        for sentence in sentences {
            let trimmedSentence = sentence.trimmingCharacters(in: .whitespaces)
            if trimmedSentence.isEmpty { continue }

            let sentenceWithPunctuation = trimmedSentence + "."

            if currentChunk.count + sentenceWithPunctuation.count > maxChunkSize && !currentChunk.isEmpty {
                chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                currentChunk = sentenceWithPunctuation + " "
            } else {
                currentChunk += sentenceWithPunctuation + " "
            }
        }

        if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Fallback: split oversized chunks by character count
        var finalChunks: [String] = []
        for chunk in chunks {
            if chunk.count <= maxChunkSize {
                finalChunks.append(chunk)
            } else {
                var remaining = chunk
                while !remaining.isEmpty {
                    let endIndex = remaining.index(remaining.startIndex, offsetBy: min(maxChunkSize, remaining.count))
                    finalChunks.append(String(remaining[..<endIndex]))
                    remaining = String(remaining[endIndex...])
                }
            }
        }

        return finalChunks
    }
}
