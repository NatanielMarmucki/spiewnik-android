#!/usr/bin/env bash
# Uruchamia testy golden w kontenerze z Linuksem, czyli na tej samej platformie co CI.
#
#   tools/golden.sh              # sprawdza, czy wygląd zgadza się z obrazami w repozytorium
#   tools/golden.sh --update     # zapisuje nowe obrazy po zamierzonej zmianie wyglądu
#
# Obrazy golden zależą od rasteryzacji czcionek, a ta różni się między macOS a Linuksem,
# dlatego obrazy powstają wyłącznie tutaj. Na macOS `flutter test` pomija te testy.
set -euo pipefail

readonly IMAGE="spiewnik-golden:3.47.4"
readonly DOCKERFILE="tools/golden.Dockerfile"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

update=false
if [[ "${1:-}" == "--update" ]]; then
  update=true
elif [[ $# -gt 0 ]]; then
  echo "Użycie: tools/golden.sh [--update]" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker nie jest dostępny." >&2
  exit 1
fi

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "Buduję obraz ${IMAGE} (tylko za pierwszym razem, kilka minut)..."
  docker build --platform linux/amd64 -f "${DOCKERFILE}" -t "${IMAGE}" .
fi

if [[ "${update}" == true ]]; then
  command=(flutter test --update-goldens test/golden)
  echo "Regeneruję obrazy golden w kontenerze..."
else
  command=(flutter test test/golden)
  echo "Sprawdzam obrazy golden w kontenerze..."
fi

# Katalogi budowania hosta (macOS) nie nadają się dla Linuksa, więc kontener ma własne.
docker run --rm \
  --platform linux/amd64 \
  -v "${repo_root}:/app" \
  -v "spiewnik-golden-pub:/root/.pub-cache" \
  -e PUB_CACHE=/root/.pub-cache \
  -w /app \
  "${IMAGE}" \
  bash -c "flutter pub get >/dev/null && tools/fetch_objectbox_lib.sh >/dev/null && ${command[*]}"

# Kontener robi `flutter pub get` na tym samym katalogu, więc .dart_tool/package_config.json
# zostaje ze ścieżkami z Linuksa i `flutter test` na hoście przestaje się kompilować.
echo "Przywracam konfigurację pakietów hosta..."
flutter pub get >/dev/null

if [[ "${update}" == true ]]; then
  echo "Gotowe. Przejrzyj zmiany w test/golden/goldens/ przed commitem."
fi
