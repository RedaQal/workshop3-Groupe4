FROM node:22-bookworm-slim

WORKDIR /app
RUN chown node:node /app

# L'image node fournit déjà l'utilisateur non-root "node"
USER node

COPY --chown=node:node package*.json ./
RUN npm install

COPY --chown=node:node . .
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]