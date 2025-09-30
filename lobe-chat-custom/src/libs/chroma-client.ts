// Gideon Studio ChromaDB Client Integration
// Vector database client for knowledge base operations

import { ChromaClient, Collection } from 'chromadb';

interface DocumentMetadata {
  filename: string;
  filepath: string;
  fileType: string;
  fileSize: number;
  uploadTimestamp: Date;
  uploaderId: string;
  chunkCount: number;
  chunkIndex: number;
  totalTokens: number;
  processingStatus: 'processing' | 'completed' | 'failed';
}

interface SearchResult {
  id: string;
  content: string;
  metadata: DocumentMetadata;
  distance: number;
  score: number;
}

export class GideonChromaClient {
  private client: ChromaClient | null = null;
  private collections: Map<string, Collection> = new Map();

  constructor() {
    // Initialize ChromaDB client connection
    this.initializeClient();
  }

  private async initializeClient(): Promise<void> {
    try {
      const chromaUrl = process.env.CHROMADB_URL || 'http://chromadb:8000';

      this.client = new ChromaClient({
        path: chromaUrl
      });

      // Test connection
      await this.client.heartbeat();
      console.log('✅ ChromaDB connection established');

    } catch (error) {
      console.error('❌ ChromaDB connection failed:', error);
      throw new Error('Failed to connect to ChromaDB');
    }
  }

  /**
   * Ensure client is connected
   */
  private async ensureClient(): Promise<ChromaClient> {
    if (!this.client) {
      await this.initializeClient();
    }

    if (!this.client) {
      throw new Error('ChromaDB client not initialized');
    }

    return this.client;
  }

  /**
   * Get or create collection for a user/knowledge base
   */
  async getOrCreateCollection(
    userId: string,
    kbName: string,
    metadata?: Record<string, any>
  ): Promise<Collection> {
    const client = await this.ensureClient();
    const collectionName = this.getCollectionName(userId, kbName);

    // Check cache first
    if (this.collections.has(collectionName)) {
      return this.collections.get(collectionName)!;
    }

    try {
      // Try to get existing collection
      const collection = await client.getCollection({
        name: collectionName
      });

      this.collections.set(collectionName, collection);
      return collection;

    } catch (error) {
      // Collection doesn't exist, create it
      const collection = await client.createCollection({
        name: collectionName
      });

      this.collections.set(collectionName, collection);
      console.log(`✅ Created collection: ${collectionName}`);
      return collection;
    }
  }

  /**
   * Store document chunks in vector database
   */
  async storeDocumentChunks(
    userId: string,
    kbName: string,
    chunks: Array<{
      id: string;
      content: string;
      metadata: DocumentMetadata;
      embeddings: number[];
    }>
  ): Promise<void> {
    const collection = await this.getOrCreateCollection(userId, kbName);

    const ids = chunks.map(chunk => chunk.id);
    const documents = chunks.map(chunk => chunk.content);
    const metadatas = chunks.map(chunk => ({
      filename: chunk.metadata.filename,
      filepath: chunk.metadata.filepath,
      fileType: chunk.metadata.fileType,
      fileSize: chunk.metadata.fileSize,
      uploaderId: chunk.metadata.uploaderId,
      chunkCount: chunk.metadata.chunkCount,
      chunkIndex: chunk.metadata.chunkIndex,
      totalTokens: chunk.metadata.totalTokens,
      processingStatus: chunk.metadata.processingStatus,
      uploaded_at: chunk.metadata.uploadTimestamp.toISOString(),
    }));

    await collection.add({
      ids,
      documents,
      embeddings: chunks.map(chunk => chunk.embeddings),
      metadatas
    });

    console.log(`✅ Stored ${chunks.length} chunks in ${this.getCollectionName(userId, kbName)}`);
  }

  /**
   * Perform semantic search across knowledge base
   */
  async searchKnowledgeBase(
    userId: string,
    kbName: string,
    queryEmbedding: number[],
    limit: number = 5,
    similarityThreshold: number = 0.1
  ): Promise<SearchResult[]> {
    const collection = await this.getOrCreateCollection(userId, kbName);

    // Query the collection
    const results = await collection.query({
      queryEmbeddings: [queryEmbedding],
      nResults: limit,
      include: ['documents', 'metadatas', 'distances'],
      where: {
        processingStatus: 'completed' // Only search completed documents
      }
    });

    // Process and filter results
    const searchResults: SearchResult[] = [];

    if (results.documents && results.documents[0] && results.metadatas && results.metadatas[0] && results.distances && results.distances[0]) {
      for (let i = 0; i < results.documents[0].length; i++) {
        const distance = results.distances[0][i] || 0;

        // Apply similarity threshold
        if (distance <= similarityThreshold) {
          continue;
        }

        const content = results.documents[0][i];
        if (!content) continue; // Skip null/undefined content

        const result: SearchResult = {
          id: `result_${i}`,
          content: content,
          metadata: results.metadatas[0][i] as any,
          distance: distance,
          score: 1 - distance // Convert distance to similarity score
        };

        searchResults.push(result);
      }
    }

    // Sort by relevance score (highest first)
    searchResults.sort((a, b) => b.score - a.score);

    return searchResults.slice(0, limit);
  }

  /**
   * Delete document chunks from knowledge base
   */
  async deleteDocumentChunks(
    userId: string,
    kbName: string,
    documentId: string
  ): Promise<void> {
    const collection = await this.getOrCreateCollection(userId, kbName);

    // Delete all chunks for this document
    await collection.delete({
      where: {
        filepath: documentId // Assume filepath contains document identifier
      }
    });

    console.log(`🗑️  Deleted chunks for document: ${documentId}`);
  }

  /**
   * Get knowledge base statistics
   */
  async getKnowledgeBaseStats(
    userId: string,
    kbName: string
  ): Promise<{
    documentCount: number;
    chunkCount: number;
    totalSize: number;
  }> {
    const collection = await this.getOrCreateCollection(userId, kbName);

    const count = await collection.count();
    const peekResult = await collection.peek({ limit: count > 0 ? Math.min(count, 100) : 0 });

    let totalSize = 0;
    if (peekResult.metadatas) {
      for (const metadata of peekResult.metadatas) {
        if (metadata && typeof metadata === 'object' && 'fileSize' in metadata) {
          totalSize += (metadata.fileSize as number) || 0;
        }
      }
    }

    return {
      documentCount: count,
      chunkCount: count,
      totalSize: totalSize
    };
  }

  /**
   * Clear entire collection (dangerous - use with caution)
   */
  async clearKnowledgeBase(
    userId: string,
    kbName: string
  ): Promise<void> {
    const collection = await this.getOrCreateCollection(userId, kbName);

    // Delete all documents in collection
    await collection.delete({});

    console.log(`🧹 Cleared entire knowledge base: ${this.getCollectionName(userId, kbName)}`);
  }

  /**
   * Generate collection name from user ID and knowledge base name
   */
  private getCollectionName(userId: string, kbName: string): string {
    // Sanitize and format collection names (ChromaDB has naming restrictions)
    const safeName = `${userId}_${kbName}`.replace(/[^a-zA-Z0-9_]/g, '_');
    return `kb_${safeName}`.toLowerCase();
  }

  /**
   * Cleanup resources
   */
  async disconnect(): Promise<void> {
    this.collections.clear();
    this.client = null;
  }
}

// Export singleton instance
let chromaClientInstance: GideonChromaClient | null = null;

export function getChromaClient(): GideonChromaClient {
  if (!chromaClientInstance) {
    chromaClientInstance = new GideonChromaClient();
  }
  return chromaClientInstance;
}

export type { DocumentMetadata, SearchResult };
