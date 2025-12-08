//
//  LLMPrompts.swift
//  Transcription App
//
//  Created by Claude on 12/8/25.
//

import Foundation

/// System prompts for LLM interactions
enum LLMPrompts {

    /// Default prompt for general assistant behavior
    static let defaultAssistant = "You are a helpful assistant."

    /// Prompt for summarizing transcriptions
    static let summarization = """
    You are a summarization assistant. Write summaries directly without any preamble.
    """

    /// Prompt for answering questions about transcriptions
    static let transcriptionQA = """
    You are a helpful assistant that answers questions about transcriptions. \
    Answer questions directly and concisely based on the provided transcription.
    """
}
