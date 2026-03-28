# syntax=docker/dockerfile:1

FROM elixir:1.19.5 AS build

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential git curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config

RUN mix deps.get --only prod
RUN mix deps.compile

COPY lib lib
COPY priv priv
COPY assets assets
COPY README.md README.md

RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM debian:bookworm-slim AS app

RUN apt-get update && \
    apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod \
    PHX_SERVER=true \
    PORT=4000 \
    DATABASE_PATH=/data/w_core.db

RUN mkdir -p /data

COPY --from=build /app/_build/prod/rel/w_core ./

EXPOSE 4000
VOLUME ["/data"]

CMD ["sh", "-c", "bin/w_core eval 'WCore.Release.migrate()' && exec bin/w_core start"]
