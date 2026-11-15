#!/bin/sh
# Packages examples/<name> with the library into build/<name>.zip (sideload or run in brs-cli).
set -e
name=${1:-hello}
root=$(cd "$(dirname "$0")/.." && pwd)
out="$root/build/$name"
rm -rf "$out" "$root/build/$name.zip"
mkdir -p "$out/source"
cp -R "$root/examples/$name/." "$out/"
cp "$root/source/AppDimens.brs" "$root/source/AppDimensTokens.brs" "$out/source/"
(cd "$out" && zip -qr "../$name.zip" .)
echo "$root/build/$name.zip"
