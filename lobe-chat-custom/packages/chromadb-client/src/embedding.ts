// Embedding utilities for ChromaDB integration
// For now, using a simple mock embedding. In production:
// - Integrate with OpenAI's embedding models
// - Or use sentence-transformers via Python service

export class EmbeddingService {
  private static instance: EmbeddingService;
  private cache: Map<string, number[]> = new Map();

  static getInstance(): EmbeddingService {
    if (!EmbeddingService.instance) {
      EmbeddingService.instance = new EmbeddingService();
    }
    return EmbeddingService.instance;
  }

  /**
   * Generate embeddings for text
   * In production, this would call an embedding API like OpenAI
   */
  async generateEmbedding(text: string): Promise<number[]> {
    if (this.cache.has(text)) {
      return this.cache.get(text)!;
    }

    // Mock embedding generation
    // In production: call OpenAI embeddings API or local model
    const embedding = this.generateMockEmbedding(text);

    this.cache.set(text, embedding);
    return embedding;
  }

  /**
   * Generate embeddings for multiple texts in batch
   */
  async generateEmbeddings(texts: string[]): Promise<number[][]> {
    const embeddings: number[][] = [];

    for (const text of texts) {
      const embedding = await this.generateEmbedding(text);
      embeddings.push(embedding);
    }

    return embeddings;
  }

  /**
   * Mock embedding generator using a simple hash-based approach
   * NOT for production - replace with real embedding service
   */
  private generateMockEmbedding(text: string): number[] {
    // Create a 1536-dimension vector (similar to OpenAI's text-embedding-ada-002)
    const vector: number[] = [];
    const seed = this.simpleHash(text);

    for (let i = 0; i < 1536; i++) {
      // Generate pseudo-random values based on seed + index
      const value = Math.sin(seed + i * 0.01) * Math.cos(seed + i * 0.007);
      vector.push(value);
    }

    // Normalize the vector to unit length
    const magnitude = Math.sqrt(vector.reduce((sum, val) => sum + val * val, 0));
    return vector.map(val => val / magnitude);
  }

  /**
   * Simple hash function for reproducible results
   */
  private simpleHash(text: string): number {
    let hash = 0;
    for (let i = 0; i < text.length; i++) {
      const char = text.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash);
  }

  /**
   * Clear cache (useful for memory management)
   */
  clearCache(): void {
    this.cache.clear();
  }
}

export default EmbeddingService;
