# Contributing to ViCut Lite

Thanks for helping. Bug reports, ideas and pull requests are all welcome.

## Start with an issue

- **Bug:** open a [bug report](https://github.com/nhanta0408/vicut-lite/issues/new?template=bug_report.yml).
- **Feature or change:** open a [feature request](https://github.com/nhanta0408/vicut-lite/issues/new?template=feature_request.yml)
  and wait for a 👍 before writing code, so your work doesn't go to waste on something that won't be merged.
- Small fixes (typos, obvious one-line bugs) can go straight to a pull request.

## Pull requests

1. Fork the repo and branch from **`develop`** (not `master`, which only holds releases).
2. Keep the change focused: one fix or feature per pull request.
3. Before opening it:
   - `swift build` with no warnings and `swift test` green
   - try it in the real app: `./scripts/build-app.sh` → `dist/ViCut Lite.app`
   - add screenshots for anything you can see
4. Open the pull request against `develop` and link the issue (`Closes #12`).

The maintainer reviews every pull request and does the merging. Changes may be asked for before merge.

## Code style

- Swift 6, SwiftUI, 2-space indent. Pure logic goes in `Sources/VicutCore` with tests in `Tests/VicutCoreTests`.
- UI uses the tokens in `Sources/VicutLite/DesignSystem/DesignTokens.swift`: no raw colors, sizes or fonts in views.
- No force unwraps (`!`). Comments explain *why*, not *what*.
- Commit messages are one short line.

## License

By contributing, you agree that your contribution is licensed under the [GPL-3.0](LICENSE), like the rest of the project.
