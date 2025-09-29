# Use a multi-stage build with Git to clone the full Lobe Chat repository
FROM node:24-slim AS source

RUN apt-get update && apt-get install -y git ca-certificates

WORKDIR /app

# Clone the complete Lobe Chat repository
RUN git clone https://github.com/lobehub/lobe-chat.git .

# Switch to Gideon Studio branding branch or keep main
# If needed, we can add customizations here

FROM node:24-slim AS builder

# Copy all source files from source stage
COPY --from=source /app /app

WORKDIR /app

# Install dependencies and build
RUN npm install -g corepack@latest && corepack enable
RUN npm run build:docker

# Production stage
FROM scratch

# Copy the built application
COPY --from=builder /app/.next/standalone /

# Set environment variables
ENV NODE_ENV="production" \
    PORT="3210" \
    HOSTNAME="0.0.0.0"

EXPOSE 3210/tcp

# Start the application
CMD ["/bin/node", "/app/startServer.js"]
