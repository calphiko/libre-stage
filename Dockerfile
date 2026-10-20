# syntax=docker/dockerfile:1.4

FROM alpine:latest as code-fetcher
RUN echo "hallo14"

ARG BRANCH=main
ENV BRANCH=$BRANCH

RUN apk add --no-cache git
RUN apk add --no-cache openssh

WORKDIR /repo
RUN git clone --depth 1 -b ${BRANCH} https://github.com/calphiko/libre-stage.git

FROM node:20-bookworm-slim as builder
WORKDIR /frontend

# Packages zuerst (für Cache)
COPY --from=code-fetcher /repo/libre-stage/frontend/package*.json ./
RUN npm ci --include=optional

# Rest kopieren
COPY --from=code-fetcher /repo/libre-stage/frontend/ ./

RUN npx svelte-kit sync
RUN npm run build
RUN npm ci --production --ignore-scripts

# Final Container
FROM python:3.14-slim

RUN useradd -m -s /bin/bash appuser
RUN apt update && apt clean

# install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
ENV UV_SYSTEM_PYTHON=1
ENV UV_NO_CACHE=1

WORKDIR /app
COPY --from=code-fetcher /repo/libre-stage/backend ./backend
COPY --from=code-fetcher /repo/libre-stage/pyproject.toml ./
COPY --from=code-fetcher /repo/libre-stage/uv.lock ./
COPY --from=code-fetcher /repo/libre-stage/version.json ./
COPY --from=code-fetcher /repo/libre-stage/alembic.ini ./

RUN uv sync --frozen --no-dev

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
