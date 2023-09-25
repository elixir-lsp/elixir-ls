FROM index.docker.io/elixir:alpine

ARG ELIXIR_LS_VERSION=v0.16.0
ARG MIX_ENV=prod

ADD . /app

WORKDIR /app

# Add build and test dependencies
RUN apk add --no-cache \
  git \
  zsh \
  bash \
  fish

CMD sh
