# Specification Quality Checklist: Pluggable version strategy

**Created**: 2026-07-06
**Feature**: [spec.md](../spec.md)

## Content Quality
- [x] No implementation details leak into the spec's WHAT/WHY
- [x] Focused on user value (apps keep build-id; libraries get honest SemVer)
- [x] All mandatory sections completed

## Requirement Completeness
- [x] No [NEEDS CLARIFICATION] markers
- [x] Requirements testable and unambiguous
- [x] Success criteria measurable
- [x] Acceptance scenarios defined (US1 build-id no-regression, US2 package-json)
- [x] Edge cases identified (invalid strategy, major-minor ignored, prerelease verbatim, shared guards)
- [x] Scope bounded (tags only; publishing is downstream/consumer)
- [x] Assumptions identified (build-id default; verbatim tagging; no manifest change)

## Feature Readiness
- [x] Every FR has acceptance criteria
- [x] Default decided and settled: build-id (incumbent deployable repos); package-json is the
      mandatory library choice — not a preference (SemVer requires it)

## Notes
- Default = `build-id`: backward-compatible for existing deployable consumers and this repo's own
  self-versioning. `package-json` is opt-in and is what any published library must use.
- All items pass; no clarifications needed (the design was resolved in discussion before speccing).
