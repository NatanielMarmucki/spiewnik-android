#!/usr/bin/env bash
# Downloads the ObjectBox C library used by unit tests (flutter test) into lib/.
# The library is not committed (see .gitignore); run this once after cloning and on CI.
#
# The C library version must match the objectbox Dart package: the Dart bindings do not
# detect C function signature mismatches. objectbox 5.3.2 requires objectbox-c 5.3.2
# (see install.sh in objectbox-dart v5.3.2).
#
# Usage: tools/fetch_objectbox_lib.sh
# Overrides (for testing the script): OBJECTBOX_PLATFORM=linux-x64, OBJECTBOX_LIB_DIR=/some/dir
set -euo pipefail

readonly C_LIBRARY_VERSION="5.3.2"
readonly DART_PACKAGE_VERSION="5.3.2"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lib_dir="${OBJECTBOX_LIB_DIR:-${repo_root}/lib}"

locked_version="$(awk '/^  objectbox:$/ {found=1} found && /version:/ {gsub(/"/, "", $2); print $2; exit}' "${repo_root}/pubspec.lock")"
if [[ "${locked_version}" != "${DART_PACKAGE_VERSION}" ]]; then
  echo "Error: pubspec.lock uses objectbox ${locked_version:-<not found>}, this script is pinned to ${DART_PACKAGE_VERSION}." >&2
  echo "Update C_LIBRARY_VERSION and the checksums to the objectbox-c version required by the new package." >&2
  exit 1
fi

if [[ -n "${OBJECTBOX_PLATFORM:-}" ]]; then
  platform="${OBJECTBOX_PLATFORM}"
else
  case "$(uname -s)-$(uname -m)" in
    Darwin-*) platform="macos-universal" ;;
    Linux-x86_64) platform="linux-x64" ;;
    Linux-aarch64 | Linux-arm64) platform="linux-aarch64" ;;
    *)
      echo "Error: unsupported platform $(uname -s) $(uname -m)." >&2
      echo "Download manually from https://github.com/objectbox/objectbox-c/releases/tag/v${C_LIBRARY_VERSION}" >&2
      exit 1
      ;;
  esac
fi

# SHA-256 of the release archives, from the GitHub release metadata.
case "${platform}" in
  macos-universal)
    archive="objectbox-macos-universal.zip"
    checksum="680c598573ede04b9762565d48d4e161ad286f786f159abb8da89353bfa1d0bc"
    library="libobjectbox.dylib"
    ;;
  linux-x64)
    archive="objectbox-linux-x64.tar.gz"
    checksum="6dbb5450c36dd11ee9074f16ecc61e79b45ff43c2082934601f3166b39c8a613"
    library="libobjectbox.so"
    ;;
  linux-aarch64)
    archive="objectbox-linux-aarch64.tar.gz"
    checksum="bdfbfbf4971057e11018ca6645697d8a40ebc7df56ccde63397cbb0e0609c0e8"
    library="libobjectbox.so"
    ;;
  *)
    echo "Error: unknown OBJECTBOX_PLATFORM '${platform}' (use macos-universal, linux-x64 or linux-aarch64)." >&2
    exit 1
    ;;
esac

url="https://github.com/objectbox/objectbox-c/releases/download/v${C_LIBRARY_VERSION}/${archive}"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

echo "Downloading objectbox-c ${C_LIBRARY_VERSION} (${platform})..."
curl --fail --silent --show-error --location --output "${work_dir}/${archive}" "${url}"

if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "${work_dir}/${archive}" | cut -d ' ' -f 1)"
else
  actual="$(shasum -a 256 "${work_dir}/${archive}" | cut -d ' ' -f 1)"
fi
if [[ "${actual}" != "${checksum}" ]]; then
  echo "Error: checksum mismatch for ${archive}: expected ${checksum}, got ${actual}." >&2
  exit 1
fi

mkdir -p "${work_dir}/extracted"
if [[ "${archive}" == *.zip ]]; then
  unzip -q "${work_dir}/${archive}" -d "${work_dir}/extracted"
else
  tar -xzf "${work_dir}/${archive}" -C "${work_dir}/extracted"
fi

mkdir -p "${lib_dir}"
cp "${work_dir}/extracted/lib/${library}" "${lib_dir}/${library}"
echo "Installed ${lib_dir}/${library}"
