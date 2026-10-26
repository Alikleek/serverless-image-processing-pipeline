#!/usr/bin/env bash
# Builds build/pillow-layer.zip for Lambda python3.13 on arm64.
#
# Downloads prebuilt manylinux aarch64 wheels instead of compiling, so it works
# on an x86_64 machine without Docker/QEMU. Lambda python3.13 runs on Amazon
# Linux 2023 (glibc 2.34), which manylinux_2_28 wheels support.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
out="$root/build/layer"
zip="$root/build/pillow-layer.zip"

rm -rf "$out" "$zip"
mkdir -p "$out/python"

python3 -m pip install \
  --requirement "$here/requirements.txt" \
  --target "$out/python" \
  --platform manylinux_2_28_aarch64 \
  --platform manylinux2014_aarch64 \
  --implementation cp \
  --python-version 3.13 \
  --only-binary=:all: \
  --no-compile \
  --quiet

(cd "$out" && python3 -m zipfile -c "$zip" python)
echo "Built $zip ($(du -h "$zip" | cut -f1))"
