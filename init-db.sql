-- Initialize database with pgvector extension for Gideon Studio
-- This script runs automatically when PostgreSQL container starts for the first time

-- Enable the pgvector extension for vector search capabilities
CREATE EXTENSION IF NOT EXISTS vector;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE gideon_studio TO gideon;

-- Verify pgvector installation
DO $$
BEGIN
    RAISE NOTICE 'pgvector extension enabled successfully for Gideon Studio';
    RAISE NOTICE 'Vector operations now available for Knowledge Base RAG functionality';
END
$$;
