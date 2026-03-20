# ============================================================
# lovable-local-cloud — Frontend Builder & Server
# Multi-stage build: Node 22 build → nginx static serve
# ============================================================

# Stage 1: Build the Vite frontend
FROM node:22-alpine AS builder

WORKDIR /app

# Supabase env vars injected at build time
ARG VITE_SUPABASE_URL=http://localhost:54321
ARG VITE_SUPABASE_PUBLISHABLE_KEY
ARG VITE_SUPABASE_PROJECT_ID=local

ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_PUBLISHABLE_KEY=$VITE_SUPABASE_PUBLISHABLE_KEY
ENV VITE_SUPABASE_PROJECT_ID=$VITE_SUPABASE_PROJECT_ID

# Copy target app from the 'app' build context
COPY --from=app package*.json ./
RUN npm ci

COPY --from=app . .
RUN npm run build

# Stage 2: Serve with nginx (SPA fallback)
FROM nginx:alpine

COPY docker/frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
