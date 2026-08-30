#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: verify_apk.sh <apk> [apk ...]" >&2
  exit 1
fi

apkanalyzer="${ANDROID_HOME:?ANDROID_HOME is required}/cmdline-tools/latest/bin/apkanalyzer"
mapping="build/app/outputs/mapping/release/mapping.txt"
if [[ ! -x "$apkanalyzer" ]]; then
  echo "apkanalyzer is unavailable: $apkanalyzer" >&2
  exit 1
fi
if [[ ! -f "$mapping" ]]; then
  echo "R8 mapping is unavailable: $mapping" >&2
  exit 1
fi

class_name="$(sed -n \
  's/^io\.flutter\.plugin\.localization\.LocalizationPlugin -> \([^:]*\):$/\1/p' \
  "$mapping" | head -n 1)"
if [[ -z "$class_name" ]]; then
  echo "LocalizationPlugin is absent from the R8 mapping" >&2
  exit 1
fi

for apk in "$@"; do
  if [[ ! -f "$apk" ]]; then
    echo "APK is missing: $apk" >&2
    exit 1
  fi
  min_sdk="$($apkanalyzer manifest min-sdk "$apk")"
  if [[ "$min_sdk" != "23" ]]; then
    echo "$apk declares minSdk $min_sdk instead of 23" >&2
    exit 1
  fi
  class_code="$($apkanalyzer dex code --class "$class_name" "$apk")"
  if grep -q 'Configuration;->getLocales()Landroid/os/LocaleList;' \
      <<< "$class_code"; then
    echo "$apk still contains the Android 7-only localization call" >&2
    exit 1
  fi
  echo "Verified Android 6 localization bytecode in $apk"
done
