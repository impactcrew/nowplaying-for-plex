# Hostile repository review

- Review the native app and the tracked Electron entry point at `2674137`, with separate passes over native UI behavior and the release pipeline.
- Prioritize faults with a concrete impact on users or maintainers. Cross-check source references, run safe local checks, and record where the evidence is limited to static review.
- Deliver a source-linked HTML review and a short repair order. Keep application and release files outside the scope of this review.

The review is in `review.html`. It covers 12 findings at the reviewed revision and records the checks and their limits. Source and metadata checks ran locally. The fresh unsigned build did not complete because Xcode's build service crashed in the sandbox.

## Repairs

Track the requested implementation in `repair-plan.html`. The release scripts, native connection behavior, window and artwork behavior, and legacy prototype are independent enough to work on in parallel. Integrate the app and test targets before final verification. A signed or published copy is a release step.

All 12 repository items are implemented. The standalone XCTest runner passed 18 tests, the optimized Swift sources built for arm64 and x86_64, and the packaging fixtures passed. The hosted Xcode run, interactive Mac and Plex checks, and final notarized-artifact check remain release acceptance tasks.
