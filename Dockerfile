#0;136;0c
# syntax=docker/dockerfile:1.4

FROM alpine:latest as code-fetcher
RUN echo "hallo14"


#ARG BRANCH=skeleton-migration
ARG BRANCH=main
ENV BRANCH=$BRANCH

RUN apk add --no-cache git
RUN apk add --no-cache openssh

WORKDIR /repo
# CLONE REPOSITORY
# COPY ../.ssh /root/.ssh
# RUN chmod 600 /root/.ssh/id_ed25519_codeberg
# RUN ssh-keyscan -t rsa codeberg.org >> ~/.ssh/known_hosts
# RUN --mount=type=ssh git clone --depth 1 -b ${BRANCH} codeberg:calphiko/libre-stage.git
RUN git clone --depth 1 -b ${BRANCH} https://codeberg.org/calphiko/libre-stage.git

FROM node:20-bookworm-slim as builder
ARG VITE_API_URL
WORKDIR /frontend

# Packages zuerst (für Cache)
COPY --from=code-fetcher /repo/libre-stage/frontend/package*.json ./
RUN rm -rf node_modules package-lock.json
RUN npm install --include=optional

# Rest kopieren
COPY --from=code-fetcher /repo/libre-stage/frontend/ ./
ENV VITE_API_URL=${VITE_API_URL}

RUN npx svelte-kit sync
RUN npm run build
RUN npm ci --production --ignore-scripts

# Final Container
FROM python:3.12-slim

RUN useradd -m -s /bin/bash appuser
RUN apt update && apt -y install python3-pip && apt clean

WORKDIR /app
COPY --from=code-fetcher /repo/libre-stage/backend ./backend
COPY --from=code-fetcher /repo/libre-stage/version.json ./


WORKDIR /app/backend
RUN pip3 install -r requirements.txt


WORKDIR /app/frontend
COPY --from=builder /frontend/package*.json ./
COPY --from=builder /frontend/node_modules ./node_modules
COPY --from=builder /frontend/build ./build

RUN apt-get update && \
    apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

ENV NODE_ENV=production
EXPOSE 3000

WORKDIR /app
COPY ./startup.sh ./
RUN chmod +x startup.sh

CMD ["sh", "/app/startup.sh"]