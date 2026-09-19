#!/usr/bin/env bash
# Runs the golden tests in a Linux container, that is on the same platform as CI.
#
#   tools/golden.sh              # checks that the UI matches the images in the repository
#   tools/golden.sh --update     # writes new images after an intended UI change
#
# Golden images depend on font rasterization, which differs between macOS and Linux,
# so the images are generated only here. On macOS `flutter test` skips these tests.
set -euo pipefail

readonly IMAGE="spiewnik-golden:3.47.4"
readonly DOCKERFILE="tools/golden.Dockerfile"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

update=false
if [[ "${1:-}" == "--update" ]]; then
  update=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: tools/golden.sh [--update]" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not available." >&2
  exit 1
fi

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "Building image ${IMAGE} (first time only, a few minutes)..."
  docker build --platform linux/amd64 -f "${DOCKERFILE}" -t "${IMAGE}" .
fi

if [[ "${update}" == true ]]; then
  command=(flutter test --update-goldens test/golden)
  echo "Regenerating golden images in the container..."
else
  command=(flutter test test/golden)
  echo "Checking golden images in the container..."
fi

# The container runs `flutter pub get` in the same directory, so .dart_tool/package_config.json
# is left with Linux paths and `flutter test` on the host stops compiling.
# A trap, not a plain line at the end: when tests fail, `set -e` cuts the script short
# and the host used to be left with the container's configuration.
restore_host_packages() {
  echo "Restoring the host package configuration..."
  flutter pub get >/dev/null
}
trap restore_host_packages EXIT

# The host's (macOS) build directories are no good for Linux, so the container has its own.
docker run --rm \
  --platform linux/amd64 \
  -v "${repo_root}:/app" \
  -v "spiewnik-golden-pub:/root/.pub-cache" \
  -e PUB_CACHE=/root/.pub-cache \
  -w /app \
  "${IMAGE}" \
  bash -c "flutter pub get >/dev/null && tools/fetch_objectbox_lib.sh >/dev/null && ${command[*]}"


if [[ "${update}" == true ]]; then
  echo "Done. Review the changes in test/golden/goldens/ before committing."
fi
