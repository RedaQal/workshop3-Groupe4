FROM node:22-bookworm-slim

WORKDIR /app

# Build tools: better-sqlite3 compiles from source
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/* \
    && chown node:node /app

# L'image node fournit déjà l'utilisateur non-root "node"
USER node

COPY --chown=node:node package*.json ./
RUN npm install

COPY --chown=node:node . .
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]