FROM elixir:1.11-alpine AS build

# install build dependencies
RUN apk add --no-cache build-base yarn git

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix do deps.get, deps.compile

# build assets
COPY assets/package.json assets/yarn.lock ./assets/
RUN yarn --cwd ./assets install

ENV NODE_ENV=production

COPY lib lib
COPY priv priv
COPY assets assets
RUN yarn --cwd ./assets run build
RUN mix phx.digest

# compile and build release
# uncomment COPY if rel/ exists
# COPY rel rel
RUN mix do compile, release

# prepare release image
FROM alpine:latest AS app
RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/fset ./

ENV HOME=/app

CMD bin/fset eval "Fset.Release.migrate" && bin/fset start
