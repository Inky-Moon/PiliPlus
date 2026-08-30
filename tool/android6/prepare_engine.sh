#!/usr/bin/env bash
set -euo pipefail

: "${FLUTTER_ROOT:?FLUTTER_ROOT is required}"
: "${ANDROID_HOME:?ANDROID_HOME is required}"

workspace="${GITHUB_WORKSPACE:-$(pwd)}"
engine_stamp_file="$FLUTTER_ROOT/bin/cache/engine.stamp"
if [[ ! -s "$engine_stamp_file" ]]; then
  echo "Flutter engine stamp is missing: $engine_stamp_file" >&2
  exit 1
fi

engine_stamp="$(tr -d '\r\n' < "$engine_stamp_file")"
original_version="1.0.0-$engine_stamp"
patched_version="$original_version-android6"
artifact_name="flutter_embedding_release"
download_base="https://storage.googleapis.com/download.flutter.io/io/flutter/$artifact_name/$original_version"
repository="$workspace/android/android6-engine-repo"
artifact_directory="$repository/io/flutter/$artifact_name/$patched_version"
temp_directory="$(mktemp -d)"
trap 'rm -rf "$temp_directory"' EXIT

android_jar="$(find "$ANDROID_HOME/platforms" -mindepth 2 -maxdepth 2 -name android.jar -print | sort -V | tail -n 1)"
if [[ ! -f "$android_jar" ]]; then
  echo "No Android platform JAR found under $ANDROID_HOME/platforms" >&2
  exit 1
fi

echo "Preparing $artifact_name:$patched_version"
echo "Compiling against $android_jar"
curl --fail --location --retry 3 --silent --show-error \
  "$download_base/$artifact_name-$original_version.jar" \
  --output "$temp_directory/engine.jar"
curl --fail --location --retry 3 --silent --show-error \
  "$download_base/$artifact_name-$original_version.pom" \
  --output "$temp_directory/engine.pom"
curl --fail --location --retry 3 --silent --show-error \
  "https://repo1.maven.org/maven2/org/javassist/javassist/3.29.2-GA/javassist-3.29.2-GA.jar" \
  --output "$temp_directory/javassist.jar"

jar tf "$temp_directory/engine.jar" >/dev/null
mkdir -p "$temp_directory/classes" "$temp_directory/patched" "$artifact_directory"
javac -cp "$temp_directory/javassist.jar" \
  -d "$temp_directory/classes" \
  "$workspace/tool/android6/EnginePatcher.java"
java -cp "$temp_directory/javassist.jar:$temp_directory/classes" \
  -Dandroid6.output="$temp_directory/patched" \
  EnginePatcher "$temp_directory/engine.jar" "$android_jar"
jar uf "$temp_directory/engine.jar" -C "$temp_directory/patched" .

localization_code="$(javap -classpath "$temp_directory/engine.jar" -c \
  io.flutter.plugin.localization.LocalizationPlugin)"
if grep -q 'getLocales' <<< "$localization_code"; then
  echo "LocalizationPlugin still calls Configuration.getLocales()" >&2
  exit 1
fi
path_utils_code="$(javap -classpath "$temp_directory/engine.jar" -c -p \
  io.flutter.util.PathUtils)"
if grep -q 'Method android/content/Context.getDataDir:' <<< "$path_utils_code"; then
  echo "PathUtils still calls Context.getDataDir()" >&2
  exit 1
fi

cp "$temp_directory/engine.jar" \
  "$artifact_directory/$artifact_name-$patched_version.jar"
sed "0,/<version>$original_version<\/version>/s//<version>$patched_version<\/version>/" \
  "$temp_directory/engine.pom" \
  > "$artifact_directory/$artifact_name-$patched_version.pom"

if ! grep -q "<version>$patched_version</version>" \
    "$artifact_directory/$artifact_name-$patched_version.pom"; then
  echo "Failed to assign the patched Maven version" >&2
  exit 1
fi

echo "Patched Flutter embedding published to $artifact_directory"
