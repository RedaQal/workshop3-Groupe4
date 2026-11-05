# ---------- Étape de build : les compilateurs restent ici ----------
FROM node:22-bookworm-slim AS builder
WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# ---------- Image finale : ni compilateurs, ni npm ----------
FROM node:22-bookworm-slim
ENV NODE_ENV=production
WORKDIR /app

# npm et yarn ne servent pas à l'exécution : on retire leurs dépendances embarquées
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx \
           /opt/yarn-* /usr/local/bin/yarn /usr/local/bin/yarnpkg \
    && chown node:node /app

COPY --from=builder --chown=node:node /app ./

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "node_modules/next/dist/bin/next", "start"]