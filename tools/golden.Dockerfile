# Image for the golden tests: the same Linux and the same Flutter version as on CI.
#
# Golden images depend on font rasterization, so they have to be generated on Linux.
# The Flutter version is pinned: a ready-made image from the internet could change the version under us
# and break the images without any change in the code.
#
# Building and usage: tools/golden.sh (builds the image itself if it is missing).

# linux/amd64 hardcoded: GitHub runners are x86-64, and the golden images have to match CI.
# On Apple Silicon the image runs under emulation, so slower, but consistent with CI.
FROM --platform=linux/amd64 debian:bookworm-slim

ARG FLUTTER_VERSION=3.47.4

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      unzip \
      xz-utils \
      libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      -o /tmp/flutter.tar.xz \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# The project directory is mounted from outside and belongs to a user other than root.
RUN git config --global --add safe.directory /opt/flutter \
    && git config --global --add safe.directory '*' \
    && flutter --version \
    && flutter precache --universal

WORKDIR /app
