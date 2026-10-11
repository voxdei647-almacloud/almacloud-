# --- Etapa 1: Construcción (Build) ---
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm install && mkdir -p node_modules

COPY . .
RUN npm run build

# --- Etapa 2: Ejecución (Runtime) ---
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/build ./build

EXPOSE 3000

CMD ["node", "build/index.js"]
