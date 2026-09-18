# Obraz do testów golden: ten sam Linux i ta sama wersja Fluttera co na CI.
#
# Obrazy golden zależą od rasteryzacji czcionek, więc muszą powstawać na Linuksie.
# Wersja Fluttera jest przypięta: gotowy obraz z internetu mógłby zmienić wersję pod nami
# i rozjechać obrazy bez żadnej zmiany w kodzie.
#
# Budowanie i użycie: tools/golden.sh (sam zbuduje obraz, jeśli go nie ma).

# linux/amd64 na sztywno: runnery GitHuba są x86-64, a obrazy golden mają zgadzać się z CI.
# Na Apple Silicon obraz chodzi pod emulacją, czyli wolniej, ale zgodnie z CI.
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

# Katalog projektu jest montowany z zewnątrz i należy do innego użytkownika niż root.
RUN git config --global --add safe.directory /opt/flutter \
    && git config --global --add safe.directory '*' \
    && flutter --version \
    && flutter precache --universal

WORKDIR /app
