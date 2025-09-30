// Gideon Studio Knowledge Base Service
// Integrates document processing with ChromaDB vector storage

import { GideonChromaClient, getChromaClient, DocumentMetadata, SearchResult } from '@/libs/chroma-client';

export interface KnowledgeBaseChunk {
  id: string;
  content: string;
  metadata: DocumentMetadata;
  embeddings?: number[];
}

export interface DocumentUploadResult {
  documentId: string;
  chunksProcessed: number;
  processingTime: number;
  status: 'success' | 'partial' | 'failed';
  error?: string;
}

export interface KnowledgeBaseSearchOptions {
  limit?: number;
  similarityThreshold?: number;
  filters?: Record<string, any>;
}

export class KnowledgeBaseService {
  private chromaClient: GideonChromaClient;

  constructor() {
    this.chromaClient = getChromaClient();
  }

  /**
   * Generate embeddings for text using OpenAI
   * Note: This would typically call the existing AI service
   * For now, this is a placeholder that returns mock embeddings
   */
  private async generateEmbeddings(text: string): Promise<number[]> {
    // TODO: Integrate with existing OpenAI/LangChain embeddings
    // For demonstration, return random embeddings
    // In production, this would call OpenAI's text-embedding API

    // Mock embeddings - replace with actual OpenAI integration
    const embeddingSize = 1536; // OpenAI text-embedding-ada-002 dimension
    const embeddings: number[] = [];
    for (let i = 0; i < embeddingSize; i++) {
      embeddings.push(Math.random() - 0.5); // Random values between -0.5 and 0.5
    }
    return embeddings;
  }

  /**
   * Process and chunk uploaded document
   */
  async processDocument(
    userId: string,
    kbName: string,
    file: File,
    content: string
  ): Promise<DocumentUploadResult> {
    const startTime = Date.now();

    try {
      // Basic metadata
      const metadata: DocumentMetadata = {
        filename: file.name,
        filepath: `${userId}/${kbName}/${file.name}`,
        fileType: file.type,
        fileSize: file.size,
        uploadTimestamp: new Date(),
        uploaderId: userId,
        chunkCount: 0,
        chunkIndex: 0,
        totalTokens: 0,
        processingStatus: 'processing'
      };

      // Chunk the document
      const chunks = await this.chunkDocument(content, metadata);

      // Generate embeddings for each chunk
      const chunksWithEmbeddings: Array<{
        id: string;
        content: string;
        metadata: DocumentMetadata;
        embeddings: number[];
      }> = [];
      for (const chunk of chunks) {
        const embeddings = await this.generateEmbeddings(chunk.content);
        chunksWithEmbeddings.push({
          ...chunk,
          embeddings
        });
      }

      // Store chunks in ChromaDB
      await this.chromaClient.storeDocumentChunks(userId, kbName, chunksWithEmbeddings);

      // Update metadata to completed
      metadata.chunkCount = chunks.length;
      metadata.processingStatus = 'completed';

      // Calculate processing time
      const processingTime = Date.now() - startTime;

      return {
        documentId: metadata.filepath,
        chunksProcessed: chunks.length,
        processingTime,
        status: 'success'
      };

    } catch (error) {
      console.error('Document processing failed:', error);

      return {
        documentId: `${userId}/${kbName}/${file.name}`,
        chunksProcessed: 0,
        processingTime: Date.now() - startTime,
        status: 'failed',
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  /**
   * Chunk document content into manageable pieces
   */
  private async chunkDocument(
    content: string,
    metadata: DocumentMetadata
  ): Promise<KnowledgeBaseChunk[]> {
    // Simple chunking strategy - split by paragraphs and sentences
    // TODO: Implement more sophisticated chunking (semantic, token-based)

    const paragraphs = content.split('\n\n').filter(p => p.trim().length > 0);
    const chunks: KnowledgeBaseChunk[] = [];

    for (let i = 0; i < paragraphs.length; i++) {
      const paragraph = paragraphs[i].trim();

      // Skip very short paragraphs
      if (paragraph.length < 50) continue;

      // If paragraph is too long, split into sentences
      if (paragraph.length > 1000) {
        const sentences = paragraph.split(/[.!?]+/).filter(s => s.trim().length > 0);
        let currentChunk = '';

        for (const sentence of sentences) {
          if (currentChunk.length + sentence.length > 1000 && currentChunk.length > 0) {
            // Create chunk
            chunks.push({
              id: `${metadata.filepath}_chunk_${chunks.length}`,
              content: currentChunk.trim(),
              metadata: {
                ...metadata,
                chunkIndex: chunks.length,
                totalTokens: this.estimateTokens(currentChunk)
              }
            });
            currentChunk = '';
          }
          currentChunk += sentence + '. ';
        }

        // Add remaining chunk
        if (currentChunk.trim().length > 0) {
          chunks.push({
            id: `${metadata.filepath}_chunk_${chunks.length}`,
            content: currentChunk.trim(),
            metadata: {
              ...metadata,
              chunkIndex: chunks.length,
              totalTokens: this.estimateTokens(currentChunk)
            }
          });
        }
      } else {
        // Use paragraph as chunk
        chunks.push({
          id: `${metadata.filepath}_chunk_${chunks.length}`,
          content: paragraph,
          metadata: {
            ...metadata,
            chunkIndex: chunks.length,
            totalTokens: this.estimateTokens(paragraph)
          }
        });
      }
    }

    return chunks;
  }

  /**
   * Search knowledge base with semantic similarity
   */
  async searchKnowledgeBase(
    userId: string,
    kbName: string,
    query: string,
    options: KnowledgeBaseSearchOptions = {}
  ): Promise<SearchResult[]> {
    const {
      limit = 5,
      similarityThreshold = 0.1,
    } = options;

    try {
      // Generate embeddings for query
      const queryEmbedding = await this.generateEmbeddings(query);

      // Search ChromaDB
      const results = await this.chromaClient.searchKnowledgeBase(
        userId,
        kbName,
        queryEmbedding,
        limit,
        similarityThreshold
      );

      return results;
    } catch (error) {
      console.error('Knowledge base search failed:', error);
      return [];
    }
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
    processingStats: {
      completed: number;
      processing: number;
      failed: number;
    };
  }> {
    try {
      const stats = await this.chromaClient.getKnowledgeBaseStats(userId, kbName);

      // Could extend this to include processing status breakdown
      return {
        ...stats,
        processingStats: {
          completed: 0,
          processing: 0,
          failed: 0
        }
      };
    } catch (error) {
      console.error('Failed to get knowledge base stats:', error);
      return {
        documentCount: 0,
        chunkCount: 0,
        totalSize: 0,
        processingStats: {
          completed: 0,
          processing: 0,
          failed: 0
        }
      };
    }
  }

  /**
   * Delete document from knowledge base
   */
  async deleteDocument(
    userId: string,
    kbName: string,
    documentId: string
  ): Promise<boolean> {
    try {
      await this.chromaClient.deleteDocumentChunks(userId, kbName, documentId);
      return true;
    } catch (error) {
      console.error('Failed to delete document:', error);
      return false;
    }
  }

  /**
   * Clear entire knowledge base (admin operation)
   */
  async clearKnowledgeBase(
    userId: string,
    kbName: string
  ): Promise<boolean> {
    try {
      await this.chromaClient.clearKnowledgeBase(userId, kbName);
      return true;
    } catch (error) {
      console.error('Failed to clear knowledge base:', error);
      return false;
    }
  }

  /**
   * Estimate token count for text chunking decisions
   * Rough approximation: 1 token ≈ 4 characters
   */
  private estimateTokens(text: string): number {
    return Math.ceil(text.length / 4);
  }
}

// Export singleton instance
let knowledgeBaseInstance: KnowledgeBaseService | null = null;

export function getKnowledgeBaseService(): KnowledgeBaseService {
  if (!knowledgeBaseInstance) {
    knowledgeBaseInstance = new KnowledgeBaseService();
  }
  return knowledgeBaseInstance;
}
