FROM --platform=_PLATFORM_ node:23-alpine AS base

# Install dependencies only when needed
FROM base AS deps

RUN apk add --no-cache libc6-compat
WORKDIR _WORK-DIR-IN-CONTAINER_

COPY pnpm-lock.yaml *.js *.json ./
RUN corepack enable pnpm && pnpm i --frozen-lockfile

FROM base AS builder

WORKDIR _WORK-DIR-IN-CONTAINER_

COPY --from=deps _WORK-DIR-IN-CONTAINER_/node_modules ./node_modules
COPY ./src ./src
COPY ./public ./public
COPY pnpm-lock.yaml *.js *.json ./

RUN corepack enable pnpm && pnpm run build

# Production image, copy all the files and run next
FROM --platform=_PLATFORM_ _FROM-IMAGE0_
USER root

EXPOSE _EXPOSE_

WORKDIR _WORK-DIR-IN-CONTAINER_

COPY --from=builder _WORK-DIR-IN-CONTAINER_/dist/ _WORK-DIR-IN-CONTAINER__PUBLIC-PATH_/
COPY ./default.conf /etc/nginx/conf.d/default.conf
