# Ponder Indexer Dockerfile
FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY indexer/package*.json ./
RUN npm ci

# Copy indexer files
COPY indexer ./

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

USER nodejs

# Expose Ponder GraphQL port
EXPOSE 42069

# Health check for Ponder GraphQL endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD node -e "require('http').get('http://localhost:42069/health', (r) => {r.statusCode === 200 ? process.exit(0) : process.exit(1)})"

# Start Ponder
CMD ["npm", "start"]