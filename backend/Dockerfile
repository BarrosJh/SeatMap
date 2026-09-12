# Etapa 1: Build da aplicação TypeScript
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY tsconfig*.json ./
COPY src/ ./src/

RUN npm run build

# Etapa 2: Dependências exclusivas de produção
FROM node:20-alpine AS deps

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts

# Etapa 3: Imagem final de Produção (Runner seguro e enxuto)
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV TZ=America/Sao_Paulo

# 1. Atualiza pacotes do Alpine OS com patches de segurança mais recentes
# 2. Remove gerenciadores de pacotes desnecessários em runtime (npm, npx, yarn, corepack) que contêm CVEs
RUN apk update && apk upgrade --no-cache && \
    rm -rf /usr/local/lib/node_modules/npm \
           /usr/local/bin/npm \
           /usr/local/bin/npx \
           /usr/local/bin/corepack \
           /opt/yarn* \
           /usr/local/bin/yarn* \
           /root/.npm \
           /var/cache/apk/*

# Copia dependências de produção e artefatos compilados
COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY src/database/*.sql ./dist/database/
COPY package.json ./

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD node -e "fetch('http://127.0.0.1:3000/api/health/live').then((response) => process.exit(response.ok ? 0 : 1)).catch(() => process.exit(1))"

USER node

CMD ["node", "dist/server.js"]
