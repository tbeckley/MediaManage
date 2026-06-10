# Build Stage
# I'd like to use alpine but glibc nonsense on alpine requires a debian-slim
FROM elixir:1.19.5-otp-26-slim AS build

RUN apt-get update && apt-get install -y \
    build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app

COPY mix.exs mix.lock ./
ENV MIX_ENV=prod
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy source
COPY lib/ lib/
COPY config/ config/
COPY templates/ templates/

# Build release
RUN mix compile
RUN mix release && date +%s > _build/prod/rel/mediamanage/buildts

CMD [ "/bin/tar", "czf", "/out/mediamanage.tar.gz", "-C", "_build/prod/rel/", "mediamanage" ]

# Runner stage
# Again, must be debian-based
FROM debian:bookworm-slim AS mediamanage

RUN apt-get update && apt-get install -y \
    ffmpeg \
    libncursesw6 \
    libstdc++6 \
    libgcc-s1 \
    zlib1g \
    openssl \
 && rm -rf /var/lib/apt/lists/*

ENV PORT=4000
ENV ENCODING="hevc,medium,24"
ENV CACHEPATH=/tmp/cache
ENV LOGLEVEL="info"
EXPOSE ${PORT}

WORKDIR /srv

COPY --from=build /app/_build/prod/rel/mediamanage /srv
ENTRYPOINT [ "/srv/bin/mediamanage", "start" ]
