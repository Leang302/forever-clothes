# React storefront + admin, served by the SSR Node server (server.js).
# VITE_API_URL is the API URL the *browser* uses and is baked into the client bundle at build time.
# At runtime: SSR_API_URL (API URL the server itself uses, e.g. http://api:8989 inside Docker),
# PUBLIC_SITE_URL (absolute site URL for share links / Open Graph tags), PORT.
FROM node:22-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ARG VITE_API_URL
ENV VITE_API_URL=${VITE_API_URL}
RUN test -n "$VITE_API_URL" || (echo "Build arg VITE_API_URL is required, e.g. https://api.example.com" && exit 1)
RUN npm run build

FROM node:22-alpine
ENV NODE_ENV=production PORT=5173
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /src/dist ./dist
COPY server.js ./
USER node
EXPOSE 5173
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=5 \
  CMD wget -qO- http://localhost:5173/ > /dev/null || exit 1
CMD ["node", "server.js"]
