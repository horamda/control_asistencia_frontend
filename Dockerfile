# syntax=docker/dockerfile:1

FROM instrumentisto/flutter:3.32 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG API_BASE_URL
ARG APP_FLAVOR=PROD
ARG APP_PROD=true
ARG MOBILE_API_PREFIX=/api/v1/mobile
ARG MOBILE_CONTRACT_VERSION=1.15.0
ARG SESSION_IDLE_TIMEOUT_MINUTES=20
ARG SESSION_MAX_AGE_HOURS=10
ARG SESSION_PROACTIVE_REFRESH_MINUTES=8

RUN test -n "$API_BASE_URL" || (echo "API_BASE_URL build arg is required" >&2; exit 1)

RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=APP_FLAVOR=${APP_FLAVOR} \
    --dart-define=APP_PROD=${APP_PROD} \
    --dart-define=MOBILE_API_PREFIX=${MOBILE_API_PREFIX} \
    --dart-define=MOBILE_CONTRACT_VERSION=${MOBILE_CONTRACT_VERSION} \
    --dart-define=SESSION_IDLE_TIMEOUT_MINUTES=${SESSION_IDLE_TIMEOUT_MINUTES} \
    --dart-define=SESSION_MAX_AGE_HOURS=${SESSION_MAX_AGE_HOURS} \
    --dart-define=SESSION_PROACTIVE_REFRESH_MINUTES=${SESSION_PROACTIVE_REFRESH_MINUTES}

FROM nginx:1.27-alpine

ENV PORT=8080

COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
