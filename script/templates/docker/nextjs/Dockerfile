FROM --platform=_PLATFORM_ _FROM-IMAGE0_ AS base

# Install dependencies only when needed
FROM base AS deps

RUN apk add --no-cache libc6-compat
WORKDIR _WORK-DIR-IN-CONTAINER_

RUN npm config set registry https://registry.npmmirror.com/

COPY .env* *.ts *.mjs *.json ./
RUN corepack enable npm && npm i -f


FROM base AS builder
WORKDIR _WORK-DIR-IN-CONTAINER_

COPY --from=deps _WORK-DIR-IN-CONTAINER_/node_modules ./node_modules
COPY ./app ./app
COPY ./public ./public
COPY .env* *.ts *.mjs *.json ./

ENV NODE_ENV=production
RUN corepack enable npm && npm run build

# Production image, copy all the files and run next
FROM base AS runner

ENV HOSTNAME="0.0.0.0"
ENV PORT=_EXPOSE_

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

USER nextjs

WORKDIR _WORK-DIR-IN-CONTAINER_

RUN mkdir _DOT-NEXT_

COPY --from=builder --chown=nextjs:nodejs _WORK-DIR-IN-CONTAINER_/public ./public
COPY --from=builder --chown=nextjs:nodejs _WORK-DIR-IN-CONTAINER_/_DOT-NEXT_/_OUTPUT_ ./
COPY --from=builder --chown=nextjs:nodejs _WORK-DIR-IN-CONTAINER_/_DOT-NEXT_/static ./_DOT-NEXT_/static

EXPOSE _EXPOSE_

CMD ["node", "server.js"]