/**
 * Document chunking utilities for RAG preprocessing
 * Splits documents into semantically meaningful chunks for vector storage
 */

export interface TextChunk {
  text: string;
  startPosition: number;
  endPosition: number;
  tokenCount: number;
  sentences: string[];
}

export interface ChunkingOptions {
  chunkSize: number;        // Target chunk size in tokens (~words)
  overlapSize: number;      // Overlap between chunks in tokens
  minChunkSize: number;     // Minimum chunk size to avoid tiny chunks
  maxChunkSize: number;     // Maximum chunk size limit
}

export class DocumentChunker {
  private static readonly TOKEN_RATIO = 0.75; // Average words per token ratio

  private defaultOptions: ChunkingOptions = {
    chunkSize: 512,      // ~400-500 words
    overlapSize: 64,     // ~50 words overlap
    minChunkSize: 128,   // ~100 words minimum
    maxChunkSize: 1024,  // ~800 words maximum
  };

  /**
   * Split document into overlapping chunks
   */
  async chunkDocument(
    content: string,
    options: Partial<ChunkingOptions> = {}
  ): Promise<TextChunk[]> {
    const config = { ...this.defaultOptions, ...options };

    // First, split into sentences
    const sentences = this.splitIntoSentences(content);
    const chunks: TextChunk[] = [];

    let currentChunk: string[] = [];
    let currentTokenCount = 0;
    let startPosition = 0;

    for (let i = 0; i < sentences.length; i++) {
      const sentence = sentences[i];
      const sentenceTokens = this.countTokens(sentence);

      // Check if adding this sentence would exceed max chunk size
      if (currentTokenCount + sentenceTokens > config.maxChunkSize) {
        // Flush current chunk if it's not empty
        if (currentChunk.length > 0) {
          chunks.push(this.createChunk(currentChunk, startPosition, content, config));
          // Start new chunk with overlap
          currentChunk = this.createOverlap(sentences, i, config.overlapSize);
          startPosition = this.getPositionFromSentences(sentences, Math.max(0, i - currentChunk.length));
          currentTokenCount = this.countTokens(currentChunk.join(' '));
        }
      }

      currentChunk.push(sentence);
      currentTokenCount += sentenceTokens;

      // Check if we should create a chunk (target size reached)
      if (currentTokenCount >= config.chunkSize) {
        if (currentTokenCount >= config.minChunkSize) {
          chunks.push(this.createChunk(currentChunk, startPosition, content, config));

          // Start new chunk with overlap
          currentChunk = this.createOverlap(sentences, i, config.overlapSize);
          startPosition = this.getPositionFromSentences(sentences, Math.max(0, i - currentChunk.length + 1));
          currentTokenCount = this.countTokens(currentChunk.join(' '));
          i = Math.max(0, i - currentChunk.length + 1); // Adjust sentence index
        }
      }
    }

    // Add final chunk
    if (currentChunk.length > 0 && currentTokenCount >= config.minChunkSize) {
      chunks.push(this.createChunk(currentChunk, startPosition, content, config));
    }

    return chunks;
  }

  /**
   * Split text into sentences
   */
  private splitIntoSentences(text: string): string[] {
    // Basic sentence splitting - in production, use more sophisticated NLP
    const sentences = text
      .split(/[.!?]+\s+/)
      .map(s => s.trim())
      .filter(s => s.length > 0)
      .map(s => s + '.');

    // Handle edge cases
    if (sentences.length === 0 && text.trim()) {
      return [text.trim()];
    }

    return sentences;
  }

  /**
   * Create overlap sentences for chunk continuity
   */
  private createOverlap(sentences: string[], currentIndex: number, overlapTokens: number): string[] {
    const overlap: string[] = [];
    let tokenCount = 0;

    // Go backwards from current index to create overlap
    for (let i = currentIndex; i >= 0 && tokenCount < overlapTokens; i--) {
      const sentence = sentences[i];
      const sentenceTokens = this.countTokens(sentence);

      if (tokenCount + sentenceTokens <= overlapTokens) {
        overlap.unshift(sentence);
        tokenCount += sentenceTokens;
      } else {
        break;
      }
    }

    return overlap;
  }

  /**
   * Create a TextChunk from sentences
   */
  private createChunk(
    sentences: string[],
    startPosition: number,
    fullText: string,
    config: ChunkingOptions
  ): TextChunk {
    const text = sentences.join(' ').trim();
    const tokenCount = this.countTokens(text);
    const endPosition = Math.min(startPosition + text.length, fullText.length);

    return {
      text,
      startPosition,
      endPosition,
      tokenCount,
      sentences: [...sentences]
    };
  }

  /**
   * Get character position from sentence array
   */
  private getPositionFromSentences(sentences: string[], sentenceIndex: number): number {
    let position = 0;
    for (let i = 0; i < sentenceIndex; i++) {
      position += sentences[i].length;
    }
    return position;
  }

  /**
   * Approximate token count
   */
  private countTokens(text: string): number {
    // Simple approximation: 0.75 tokens per word on average
    const wordCount = text.split(/\s+/).length;
    return Math.ceil(wordCount * DocumentChunker.TOKEN_RATIO);
  }

  /**
   * Get chunking statistics
   */
  getChunkingStats(chunks: TextChunk[]): {
    totalChunks: number;
    averageChunkSize: number;
    totalTokens: number;
    tokenRange: { min: number; max: number };
  } {
    if (chunks.length === 0) {
      return {
        totalChunks: 0,
        averageChunkSize: 0,
        totalTokens: 0,
        tokenRange: { min: 0, max: 0 }
      };
    }

    const tokenCounts = chunks.map(c => c.tokenCount);
    const totalTokens = tokenCounts.reduce((sum, count) => sum + count, 0);

    return {
      totalChunks: chunks.length,
      averageChunkSize: Math.round(totalTokens / chunks.length),
      totalTokens,
      tokenRange: {
        min: Math.min(...tokenCounts),
        max: Math.max(...tokenCounts)
      }
    };
  }
}

export default DocumentChunker;
