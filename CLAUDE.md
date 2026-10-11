# CLAUDE.md

## Pushing to git

Never push without explicit approval from the user. Every push must be a release:

1. Bump `version:` in `pubspec.yaml`: increment the patch number and the build number
   (e.g. `1.0.19+20` -> `1.0.20+21`). Use a minor/major bump only if the user asks.
2. Commit the bump: `Bump version to <x.y.z>+<build>`.
3. Create an annotated tag `v<x.y.z>` on that commit (`git tag -a v1.0.20 -m "v1.0.20"`).
4. Show the user the new version, the tag and the commits being pushed, and ask for approval.
5. Only after approval: `git push --follow-tags`.
