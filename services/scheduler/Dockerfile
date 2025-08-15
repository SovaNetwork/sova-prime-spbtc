# Scheduler Service
FROM node:20-alpine

WORKDIR /app

# Install wget for healthcheck
RUN apk add --no-cache wget

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy Prisma schema and generate client
COPY prisma ./prisma/
RUN npx prisma generate

# Copy source files
COPY tsconfig.json ./
COPY src ./src/
COPY lib ./lib/

# Build TypeScript
RUN npm run build

# Copy migration script
COPY scripts/migrate.sh /app/scripts/migrate.sh
RUN chmod +x /app/scripts/migrate.sh

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 3001

# Start script that runs migrations then starts the service
CMD ["sh", "-c", "/app/scripts/migrate.sh && node dist/src/index.js"]