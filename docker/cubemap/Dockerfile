FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends cubemap && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["cubemap"]
