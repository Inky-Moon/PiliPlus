# Repository Guidelines

## Project Structure & Module Organization

PiliPlus is a Flutter client. Application code starts at `lib/main.dart`; keep UI and screens in `lib/pages/`, API clients in `lib/http/` and `lib/grpc/`, domain data in `lib/models/` or `lib/models_new/`, shared services in `lib/services/`, and reusable helpers in `lib/utils/`. The local danmaku renderer is a separate package under `packages/canvas_danmaku/`. Images, fonts, shaders, and screenshots belong in `assets/`. Native integration lives in `android/`, `ios/`, `linux/`, `macos/`, and `windows/`; Flutter SDK patches and build helpers are in `lib/scripts/`.

## Build, Test, and Development Commands

Use Flutter 3.47.2, pinned by `.fvmrc` and `pubspec.yaml` (prefix commands with `fvm` when using FVM).

- `flutter pub get` — resolve application and local-package dependencies.
- `flutter run` — launch the app on a connected device or selected desktop target.
- `flutter analyze` — run `flutter_lints` plus repository-specific analyzer rules.
- `dart format .` — format Dart sources using the configured trailing-comma behavior.
- `flutter test` — execute all tests once a `test/` suite is present.
- `flutter build apk --release --split-per-abi --android-project-arg dev=1` — reproduce the unsigned Android PR build. Release automation also applies `lib/scripts/patch.ps1` and uses an ignored `pili_release.json`.

## Coding Style & Naming Conventions

Follow standard Dart formatting (two-space indentation). Use `snake_case.dart` filenames, `UpperCamelCase` types, and `lowerCamelCase` members. Prefer package imports, explicit return types, `const` values/widgets, and structured logging over `print`; these are analyzer-enforced. Do not manually edit generated `*.g.dart`, Android bindings, or generated gRPC sources.

## Testing Guidelines

No test files or coverage threshold are currently tracked. Add unit and widget tests under `test/`, mirroring the relevant `lib/` path, and name files `*_test.dart`. Use `flutter_test`, keep tests deterministic, and run both `flutter test` and `flutter analyze` before submitting.

## Commit & Pull Request Guidelines

History favors short, imperative subjects with prefixes such as `feat:`, `fix:`, `ci:`, `style:`, `chore:`, `opt:`, and `refa:`. Keep each commit focused and reference issues where applicable (for example, `fix: handle empty subtitle list (#123)`). Pull requests should explain behavior changes, affected platforms, and verification performed; link related issues and include before/after screenshots for UI work. Never commit signing keys, credentials, local logs, or `pili_release.json`.
