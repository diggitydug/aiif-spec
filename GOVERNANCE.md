# AIIF Governance

## 1. Purpose

This document defines how the AI Interface Format (AIIF) standard is maintained, evolved, and released.

Goals of governance:

- Keep AIIF stable and predictable for adopters.
- Allow improvements without surprising breaking changes.
- Provide transparent decision-making and release criteria.

This governance applies to all normative and supporting artifacts in this repository, including:

- `AIIF-Spec.md`
- `AIIF-Conformance-Checklist.json`
- validator scripts under `tools/`
- validation fixtures under `fixtures/validation/`

## 2. Scope and Non-Scope

### In scope

- Normative specification language and structure.
- Conformance definitions and machine-checkable checks.
- Reference examples and validator behavior.
- Release tags and changelog policy.

### Out of scope

- Product-specific API design preferences.
- Enforcement of adoption in external organizations.
- Legal/commercial policy beyond repository license terms.

## 3. Roles and Responsibilities

## 3.1 Maintainers

Maintainers are responsible for:

- triaging issues and proposals,
- reviewing and approving changes,
- publishing releases,
- ensuring governance and versioning policies are followed.

## 3.2 Editors

Editors maintain editorial quality and consistency of the spec and related docs.

Editors may approve editorial-only changes directly, but normative changes require Maintainer approval.

## 3.3 Contributors

Contributors may submit issues and pull requests for any part of the standard.

## 4. Decision Model

AIIF uses a consensus-first model with explicit fallback:

1. **Consensus attempt:** maintainers discuss proposal and seek alignment.
2. **Fallback decision:** if consensus is not reached within the review window, maintainers decide by simple majority.
3. **Tie-break:** if voting is tied, the release owner for that cycle makes the final call.

All accepted normative changes MUST include rationale and compatibility impact notes in the PR.

## 5. Change Classes

Every change MUST be classified as one of:

- **Editorial:** wording/format improvements with no normative impact.
- **Additive (non-breaking):** introduces optional fields or clarifications that preserve compatibility.
- **Breaking:** removes/renames required fields or changes normative semantics.

## 6. Proposal and Review Process

Normative or behavioral changes SHOULD use a proposal issue or PR section containing:

- Problem statement
- Proposed change
- Compatibility impact
- Migration guidance (if any)
- Conformance/checklist impact
- Validator/test impact

### Review windows

- Editorial changes: minimum 3 calendar days review.
- Additive changes: minimum 7 calendar days review.
- Breaking changes: minimum 14 calendar days review.

Maintainers MAY extend windows for high-impact changes.

## 7. Versioning and Compatibility Policy

AIIF follows semantic versioning for the standard:

- **Major:** breaking changes
- **Minor:** backward-compatible additive changes
- **Patch:** editorial clarifications and non-semantic corrections

Compatibility guarantees:

- Minor and patch releases MUST preserve compatibility with prior minor versions in the same major line.
- Unknown-field tolerance MUST be preserved according to the spec.

## 8. Deprecation Policy

For any deprecated feature or behavior:

- Deprecation MUST be explicitly documented in the spec and changelog.
- A replacement SHOULD be provided.
- A minimum deprecation window of one minor release SHOULD be observed before removal.
- Removal requires a major version release.

## 9. Release Lifecycle

Each release progresses through:

1. **Draft** — active edits and discussion.
2. **Release Candidate (RC)** — feature freeze, validation focus.
3. **Final** — published stable version.

A release MAY be promoted only if all release gates pass.

## 10. Release Gates

Before final release, maintainers MUST confirm:

- Spec and checklist consistency is verified.
- Reference validators run successfully against baseline fixtures.
- `valid.aiif.json` passes.
- `invalid.aiif.json` fails expected MUST checks.
- Changelog is updated.

For stricter release quality, maintainers SHOULD also validate runtime/integration checks for documentation endpoints and agent behavior patterns.

## 11. Conformance Program Model

AIIF recognizes two conformance layers:

- **Static conformance:** validated from AIIF documents using checklist + validators.
- **Runtime conformance:** validated against live API behavior and/or agent execution.

A claim of "fully conformant implementation" SHOULD cover both layers.

## 12. Transparency and Records

The project SHOULD maintain:

- changelog entries for released versions,
- rationale in PR discussions for normative changes,
- clear mapping between checklist updates and spec sections.

## 13. Appeals and Dispute Resolution

If a contributor disagrees with a governance or technical decision:

1. Open an issue labeled governance or standards decision.
2. Provide technical rationale and alternative proposal.
3. Maintainers review and respond within 14 calendar days.

If disagreement remains, maintainers issue a final written decision and rationale.

## 14. Governance Amendments

Changes to this `GOVERNANCE.md` require:

- explicit proposal,
- at least 7 calendar days review,
- maintainer approval by majority.

Governance changes SHOULD take effect in the next release cycle unless marked urgent.
