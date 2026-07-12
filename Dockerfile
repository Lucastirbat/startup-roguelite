FROM node:20-alpine
WORKDIR /app
COPY deploy/server.js ./server.js
COPY build/web ./public
EXPOSE 8080
CMD ["node", "server.js"]
