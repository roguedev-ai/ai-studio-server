import { ChromaClient, Collection } from 'chromadb';

export interface DocumentMetadata {
  // Core metadata
  filename: string;
  filepath: string;
  fileType: string;
  fileSize: number;
  uploadTimestamp: Date;
  uploaderId?: string;

  // Content metadata
  title?: string;
  author?: string;
  creationDate?: Date;
  modificationDate?: Date;
  language?: string;
  summary?: string;

  // Processing metadata
  chunkCount: number;
  processingStatus: 'pending' | 'processing' | 'completed' | 'failed';
  processingTime?: number;
  errorMessage?: string;

  // Vector metadata
  embeddingModel: string;
  chunkSize: number;
  overlapSize: number;
}

export interface ChunkMetadata extends DocumentMetadata {
  chunkIndex: number;
  startPosition: number;
  endPosition: number;
  tokenCount: number;
  embeddingVersion: string;
}

export interface SearchResult {
  id: string;
  content: string;
  metadata: DocumentMetadata;
  distance: number;
  score: number;
}

export class GideonChromaClient {
  private client: ChromaClient;
  private collections: Map<string, Collection> = new Map();

  constructor(private chromaUrl: string = 'http://chromadb:8000') {
    this.client = new ChromaClient({ path: this.chromaUrl });
  }

  /**
   * Initialize a collection for a knowledge base
   */
  async initializeCollection(collectionName: string): Promise<Collection> {
    try {
      const collection = await this.client.getOrCreateCollection({
        name: collectionName,
        metadata: { "hnsw:space": "cosine" }
      });

      this.collections.set(collectionName, collection);
      return collection;
    } catch (error) {
      throw new Error(`Failed to initialize collection ${collectionName}: ${error}`);
    }
  }

  /**
   * Get or create a collection
   */
  getCollection(collectionName: string): Collection | null {
    return this.collections.get(collectionName) || null;
  }

  /**
   * Store document chunks in ChromaDB
   */
  async storeDocumentChunks(
    collectionName: string,
    chunks: { id: string; content: string; metadata: ChunkMetadata; embeddings: number[] }[]
  ): Promise<void> {
    const collection = this.collections.get(collectionName);
    if (!collection) {
      throw new Error(`Collection ${collectionName} not initialized`);
    }

    const ids = chunks.map(chunk => chunk.id);
    const documents = chunks.map(chunk => chunk.content);
    const metadatas = chunks.map(chunk => chunk.metadata);
    const embeddings = chunks.map(chunk => chunk.embeddings);

    try {
      await collection.add({
        ids,
        documents,
        metadatas,
        embeddings
      });
    } catch (error) {
      throw new Error(`Failed to store document chunks: ${error}`);
    }
  }

  /**
   * Search for similar documents
   */
  async searchSimilar(
    collectionName: string,
    queryEmbedding: number[],
    limit: number = 5
  ): Promise<SearchResult[]> {
    const collection = this.collections.get(collectionName);
    if (!collection) {
      throw new Error(`Collection ${collectionName} not initialized`);
    }

    try {
      const results = await collection.query({
        queryEmbeddings: [queryEmbedding],
        nResults: limit,
        include: ['documents', 'metadatas', 'distances']
      });

      return this.formatResults(results);
    } catch (error) {
      throw new Error(`Search failed: ${error}`);
    }
  }

  /**
   * Format ChromaDB results into our interface
   */
  private formatResults(results: any): SearchResult[] {
    const formattedResults: SearchResult[] = [];

    if (!results.ids || !results.ids[0]) return [];

    const ids = results.ids[0];
    const documents = results.documents?.[0] || [];
    const metadatas = results.metadatas?.[0] || [];
    const distances = results.distances?.[0] || [];

    for (let i = 0; i < ids.length; i++) {
      // Calculate relevance score (inverse of distance for cosine similarity)
      const distance = distances[i] || 0;
      const score = Math.max(0, 1 - distance);

      formattedResults.push({
        id: ids[i],
        content: documents[i] || '',
        metadata: metadatas[i] || {},
        distance,
        score
      });
    }

    return formattedResults.sort((a, b) => b.score - a.score);
  }

  /**
   * Delete documents from collection
   */
  async deleteDocuments(collectionName: string, ids: string[]): Promise<void> {
    const collection = this.collections.get(collectionName);
    if (!collection) {
      throw new Error(`Collection ${collectionName} not initialized`);
    }

    try {
      await collection.delete({ ids });
    } catch (error) {
      throw new Error(`Delete failed: ${error}`);
    }
  }

  /**
   * Get collection statistics
   */
  async getCollectionStats(collectionName: string): Promise<{ count: number; ids: string[] }> {
    const collection = this.collections.get(collectionName);
    if (!collection) {
      throw new Error(`Collection ${collectionName} not initialized`);
    }

    try {
      const count = await collection.count();
      return { count, ids: [] };
    } catch (error) {
      throw new Error(`Stats retrieval failed: ${error}`);
    }
  }

  /**
   * Test connection to ChromaDB
   */
  async testConnection(): Promise<boolean> {
    try {
      await this.client.heartbeat();
      return true;
    } catch (error) {
      console.error('ChromaDB connection test failed:', error);
      return false;
    }
  }

  /**
   * Collection naming strategy
   */
  static getCollectionName(userId: string, kbName: string): string {
    const safeName = `${userId}_${kbName}`.replace(/[^a-zA-Z0-9_]/g, '_');
    return `kb_${safeName}`.toLowerCase();
  }
}

export default GideonChromaClient;
