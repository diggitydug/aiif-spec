# AIIF Spec

AI Interface Format (AIIF) is a compact, deterministic, machine-readable API contract format optimized for AI agents.

AIIF defines how APIs describe endpoints, parameters, request/response schemas, and errors in a way that is easier for LLM-based agents to parse reliably and use with lower token cost.

## What this project is

This repository contains the AIIF v1 specification and reference examples.

The project goal is to provide a practical, implementation-friendly standard for agent-to-API interaction with clear normative behavior (MUST/SHOULD/MAY), predictable structure, and minimal ambiguity.

## Why AIIF exists

Traditional API documentation formats are excellent for humans and broad tooling, but can be verbose for agent runtime use.

AIIF focuses on:

- Minimal contract surface area for lower token usage.
- Deterministic field semantics to reduce hallucinated calls.
- Stable, portable structure that is language/framework agnostic.
- Explicit agent behavior rules for safer automation.
- Compatibility with existing standards (especially OpenAPI), not replacement.

## Core v1 model

AIIF v1 documents include:

- Top-level metadata (`aiif_version`, `info`, optional `auth`).
- Global behavior guidance (`agent_rules`) as plain-English instruction strings.
- Endpoint contracts (`name`, `method`, `path`, `params` with machine-readable constraints, `request`, `request_content_type`, `response`, `response_content_type`, `errors`).
- Reusable schemas and errors.
- Deterministic conformance constraints (uniqueness rules, stable ordering guidance, unknown-field handling).

AIIF-compliant APIs must expose selective documentation endpoints:

- `GET /ai-docs` (full document)
- `GET /ai-docs/{endpoint}` (single-endpoint contract)
- `GET /ai-docs/summary` (lightweight endpoint catalog)
- `GET /ai-docs/auth` (authentication flow documentation; required when `auth.type` is not `none`)

These endpoints let agents fetch only what they need for a task.

## Repository Structure

- `AIIF-Spec.md` — Normative AIIF specification (authoritative).
- `AIIF-Examples.md` — Non-normative examples and reference payloads.
- `AIIF-Minimal-Compliant.aiif.json` — Standalone minimal AIIF-compliant document.
- `AIIF-Conformance-Checklist.json` — Machine-checkable conformance checklist profile.
- `GOVERNANCE.md` — Change control, release policy, and standard decision model.
- `CHANGELOG.md` — Brief project change record.
- `LICENSE` — Apache 2.0 license.

## How to use this repository

- If you are implementing AIIF in an API server, start with `AIIF-Spec.md` and build `/ai-docs`, `/ai-docs/{endpoint}`, and `/ai-docs/summary` first.
- If you are building an agent/tooling client, use `AIIF-Spec.md` for normative behavior and `AIIF-Examples.md` for integration test fixtures.
- Use examples for guidance only; normative requirements are defined in the spec file.
- Use the conformance checklist in Section 12 of `AIIF-Spec.md` as a release-readiness validation aid.
- Use Security Considerations in Section 13 of `AIIF-Spec.md` when exposing AIIF endpoints on public APIs.
- Use `AIIF-Minimal-Compliant.aiif.json` for smoke-testing parsers and validators.
- Use `AIIF-Conformance-Checklist.json` to automate implementation and agent conformance checks.

## Conformance checklist and validator

`AIIF-Conformance-Checklist.json` is a machine-readable set of conformance checks derived from the spec.

Each check has:

- `id`: Stable identifier for automation and reporting.
- `category`: `implementation` (server/docs contract) or `agent` (runtime behavior).
- `level`: `MUST` or `SHOULD` severity.
- `spec_section`: The normative section the check maps to.
- `description`: What to validate.

The repository includes three static AIIF document validators:

- `tools/validate-aiif.py` (Python)
- `tools/validate-aiif.ps1` (standalone PowerShell, no Python required)
- `tools/validate-aiif.sh` (standalone Bash + `jq`, no Python required)

### Run validator

From the repository root:

`python tools/validate-aiif.py --aiif AIIF-Minimal-Compliant.aiif.json`

PowerShell:

`./tools/validate-aiif.ps1 -Aiif AIIF-Minimal-Compliant.aiif.json`

Bash:

`./tools/validate-aiif.sh --aiif AIIF-Minimal-Compliant.aiif.json`

Run all validators (single command):

`./tools/validate-aiif-all.ps1 -Aiif AIIF-Minimal-Compliant.aiif.json`

Prerequisite for Bash validator:

- `jq` must be installed and available on `PATH`.

Optional flags:

- `--checklist <path>`: Use a non-default checklist file.
- `--strict-should`: Treat `SHOULD` failures as non-compliant exit status.

PowerShell equivalents:

- `-Checklist <path>`: Use a non-default checklist file.
- `-StrictShould`: Treat `SHOULD` failures as non-compliant exit status.

`validate-aiif-all.ps1` additional option:

- `-RequireAll`: Return non-zero if any validator is skipped (for strict CI environments).

### Exit codes

- `0`: All `MUST` checks pass (and all `SHOULD` checks pass if `--strict-should` is used).
- `1`: One or more conformance checks failed per selected strictness.
- `2`: Input/JSON/argument error.

### What the script validates today

- Required top-level shape (`aiif_version`, `info`, `endpoints`).
- Endpoint uniqueness (`name`, and `(method, path)`).
- Parameter uniqueness by `(name, location)`.
- Presence/shape checks aligned to checklist IDs (for example `auth_required`, `response_content_type`, and constraints publication).

Notes:

- These scripts perform static document validation (JSON contract quality).
- Runtime endpoint behavior checks (such as verifying that `/ai-docs/auth` is actually served) should be validated in integration tests using the same checklist IDs.

### Validation fixtures

Reusable test fixtures are available in `fixtures/validation`:

- `valid.aiif.json` — Expected to pass (`exit 0`).
- `mostly-valid.aiif.json` — Expected to pass MUST checks but fail some SHOULD checks (`exit 0` unless strict mode is enabled).
- `invalid.aiif.json` — Expected to fail one or more MUST checks (`exit 1`).

Example:

- `python tools/validate-aiif.py --aiif fixtures/validation/valid.aiif.json`
- `./tools/validate-aiif.ps1 -Aiif fixtures/validation/mostly-valid.aiif.json`
- `./tools/validate-aiif.sh --aiif fixtures/validation/invalid.aiif.json`

### Recommended agent runtime flow

1. Fetch `GET /ai-docs/summary` to discover available operations, load `agent_rules`, and identify endpoint-level `auth_required` hints.
2. If the API is protected, fetch `GET /ai-docs/auth` to load credential acquisition/application/refresh guidance.
3. Fetch `GET /ai-docs/{endpoint}` for the chosen operation to get exact request/response/error contract details.
4. Execute the API call using only documented fields and behaviors.

## Project status

AIIF v1.0 is finalized as the current standard in this repository.

Formalization and governance can evolve over time; the spec file remains the source of truth for current normative requirements.

## Quick Links

- Spec: `AIIF-Spec.md`
- Examples: `AIIF-Examples.md`
- Minimal compliant example: `AIIF-Minimal-Compliant.aiif.json`
- Machine-checkable checklist: `AIIF-Conformance-Checklist.json`
- Governance: `GOVERNANCE.md`
- Changelog: `CHANGELOG.md`
- License: `LICENSE`
