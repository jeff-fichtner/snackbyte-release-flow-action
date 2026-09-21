# Specification Quality Checklist: Tag prefix

**Created**: 2026-09-21
**Feature**: [spec.md](../spec.md)

## Content Quality
- [x] No implementation details leak into the spec's WHAT/WHY
- [x] Focused on user value (two releasables in one repo; existing consumers untouched)
- [x] All mandatory sections completed

## Requirement Completeness
- [x] No [NEEDS CLARIFICATION] markers
- [x] Requirements testable and unambiguous
- [x] Success criteria measurable
- [x] Acceptance scenarios defined (US1 no-regression + un-prefixed blindness, US2 prefixed namespace)
- [x] Edge cases identified (invalid prefix, prefix-of-prefix, two namespaces on one commit,
      repository-tree reuse key, shared guards)
- [x] Scope bounded (tag namespace + package.json path; manifest, resolve-env, suffix unchanged)
- [x] Assumptions identified (empty defaults; repository tree key; package.json is a path input;
      Constitution III amended)

## Feature Readiness
- [x] Every FR has acceptance criteria
- [x] Default decided and settled: `""` (byte-identical); the prefix is opt-in per releasable

## Notes
- The package.json-location gap for a subdirectory library was found while building, surfaced,
  and resolved by maintainer decision in this feature (`package-json` path input) — see plan.md.
