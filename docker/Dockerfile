# Stage 1 – Build
FROM node:18-alpine AS builder

WORKDIR /app

COPY app/package*.json ./

RUN npm install --production

COPY app/ .

# Stage 2 – Runtime
FROM node:18-alpine

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app /app

USER appuser

EXPOSE 3000

CMD ["node", "server.js"]