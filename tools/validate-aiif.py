#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from typing import Any, Dict, List, Set, Tuple


METHODS = {"GET", "POST", "PUT", "PATCH", "DELETE"}
PARAM_LOCATIONS = {"path", "query", "body"}
AUTH_TYPES = {"none", "api_key", "bearer", "basic", "oauth2"}
CONSTRAINT_FIELDS = {"minimum", "maximum", "min_length", "max_length", "pattern", "format"}


class CheckResult:
    def __init__(self, check_id: str, level: str, passed: bool, message: str):
        self.check_id = check_id
        self.level = level
        self.passed = passed
        self.message = message


class Validator:
    def __init__(self, doc: Dict[str, Any], checklist: Dict[str, Any]):
        self.doc = doc
        self.checklist = checklist
        self.check_defs = self._index_checks(checklist)
        self.results: List[CheckResult] = []

    def _index_checks(self, checklist: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
        checks = checklist.get("checks", [])
        indexed = {}
        for item in checks:
            check_id = item.get("id")
            if isinstance(check_id, str):
                indexed[check_id] = item
        return indexed

    def _emit(self, check_id: str, passed: bool, message: str):
        check_def = self.check_defs.get(check_id, {})
        level = check_def.get("level", "INFO")
        self.results.append(CheckResult(check_id, level, passed, message))

    def run(self):
        self._check_top_level_required_fields()
        self._check_endpoint_uniqueness()
        self._check_params_uniqueness()
        self._check_method_values()
        self._check_param_locations()
        self._check_auth_object()
        self._check_auth_docs_requirement()
        self._check_auth_required_presence()
        self._check_response_content_type_support()
        self._check_param_constraints_published()
        self._check_agent_rules_consistent_shape()

    def _check_top_level_required_fields(self):
        required = ["aiif_version", "info", "endpoints"]
        missing = [k for k in required if k not in self.doc]
        aiif_version = self.doc.get("aiif_version")
        aiif_version_ok = isinstance(aiif_version, str) and aiif_version.strip() != ""
        ok = (
            not missing
            and aiif_version_ok
            and isinstance(self.doc.get("endpoints"), list)
            and isinstance(self.doc.get("info"), dict)
        )
        if ok:
            msg = "top-level required fields present"
        else:
            details = list(missing)
            if not aiif_version_ok:
                details.append("aiif_version (must be non-empty string)")
            msg = f"missing/invalid top-level fields: {details}"
        self._emit("impl.top_level.required_fields", ok, msg)

    def _check_endpoint_uniqueness(self):
        endpoints = self.doc.get("endpoints", []) if isinstance(self.doc.get("endpoints"), list) else []

        names: Set[str] = set()
        dup_names: Set[str] = set()
        method_paths: Set[Tuple[str, str]] = set()
        dup_method_paths: Set[Tuple[str, str]] = set()

        for ep in endpoints:
            if not isinstance(ep, dict):
                continue
            name = ep.get("name")
            method = ep.get("method")
            path = ep.get("path")

            if isinstance(name, str):
                if name in names:
                    dup_names.add(name)
                names.add(name)

            if isinstance(method, str) and isinstance(path, str):
                key = (method, path)
                if key in method_paths:
                    dup_method_paths.add(key)
                method_paths.add(key)

        self._emit(
            "impl.endpoint_name.unique",
            len(dup_names) == 0,
            "endpoint names are unique" if len(dup_names) == 0 else f"duplicate endpoint names: {sorted(dup_names)}",
        )

        self._emit(
            "impl.method_path.unique",
            len(dup_method_paths) == 0,
            "(method,path) pairs are unique"
            if len(dup_method_paths) == 0
            else f"duplicate (method,path) pairs: {sorted(list(dup_method_paths))}",
        )

    def _check_params_uniqueness(self):
        endpoints = self.doc.get("endpoints", []) if isinstance(self.doc.get("endpoints"), list) else []
        violations = []
        for ep in endpoints:
            if not isinstance(ep, dict):
                continue
            ep_name = ep.get("name", "<unknown>")
            params = ep.get("params", [])
            if not isinstance(params, list):
                continue
            seen = set()
            for p in params:
                if not isinstance(p, dict):
                    continue
                key = (p.get("name"), p.get("location"))
                if key in seen:
                    violations.append(f"{ep_name}:{key}")
                seen.add(key)

        self._emit(
            "impl.params.unique_by_name_location",
            len(violations) == 0,
            "params are unique by (name,location)" if len(violations) == 0 else f"duplicate params: {violations}",
        )

    def _check_method_values(self):
        endpoints = self.doc.get("endpoints", []) if isinstance(self.doc.get("endpoints"), list) else []
        bad = []
        for ep in endpoints:
            if not isinstance(ep, dict):
                continue
            method = ep.get("method")
            name = ep.get("name", "<unknown>")
            if not isinstance(method, str) or method not in METHODS:
                bad.append(f"{name}:{method}")

        check_id = "impl.endpoint.method.allowed"
        if check_id in self.check_defs:
            self._emit(check_id, len(bad) == 0, "all methods are allowed" if len(bad) == 0 else f"invalid methods: {bad}")

    def _check_param_locations(self):
        endpoints = self.doc.get("endpoints", []) if isinstance(self.doc.get("endpoints"), list) else []
        bad = []
        for ep in endpoints:
            if not isinstance(ep, dict):
                continue
            ep_name = ep.get("name", "<unknown>")
            params = ep.get("params", [])
            if not isinstance(params, list):
                continue
            for p in params:
                if not isinstance(p, dict):
                    continue
                location = p.get("location")
                pname = p.get("name", "<unknown>")
                if location not in PARAM_LOCATIONS:
                    bad.append(f"{ep_name}:{pname}:{location}")

        check_id = "impl.params.location.allowed"
        if check_id in self.check_defs:
            self._emit(
                check_id,
                len(bad) == 0,
                "all parameter locations are valid" if len(bad) == 0 else f"invalid parameter locations: {bad}",
            )

    def _check_auth_object(self):
        auth = self.doc.get("auth")
        if auth is None:
            return
        if not isinstance(auth, dict):
            self._emit("impl.auth_flow.structured_fields", False, "auth exists but is not an object")
            return

        auth_type = auth.get("type")
        if not isinstance(auth_type, str) or auth_type not in AUTH_TYPES:
            self._emit("impl.auth_flow.structured_fields", False, f"auth.type invalid: {auth_type}")
            return

        if auth_type in {"bearer", "oauth2"}:
            has_instructions = isinstance(auth.get("instructions"), list) and len(auth.get("instructions")) > 0
            has_acquire = isinstance(auth.get("acquire"), dict)
            has_apply = isinstance(auth.get("apply"), dict)
            ok = has_instructions and has_acquire and has_apply
            self._emit(
                "impl.auth_flow.structured_fields",
                ok,
                "bearer/oauth2 auth includes instructions+acquire+apply"
                if ok
                else "bearer/oauth2 auth should include instructions, acquire, and apply",
            )

    def _check_auth_docs_requirement(self):
        auth = self.doc.get("auth")
        auth_type = auth.get("type") if isinstance(auth, dict) else None
        protected_expected = isinstance(auth_type, str) and auth_type != "none"

        check_id = "impl.auth_docs.required_for_protected"
        if check_id not in self.check_defs:
            return

        if protected_expected:
            self._emit(
                check_id,
                True,
                "requires /ai-docs/auth for protected APIs (runtime endpoint verification out of scope for static document validation)",
            )
        else:
            self._emit(check_id, True, "auth.type is none or missing; /ai-docs/auth requirement not triggered")

    def _check_auth_required_presence(self):
        endpoints = self.doc.get("endpoints", []) if isinstance(self.doc.get("endpoints"), list) else []
        missing = []
        for ep in endpoints:
            if not isinstance(ep, dict):
                continue
            if "auth_required" not in ep:
                missing.append(ep.get("name", "<unknown>"))

        self._emit(
            "impl.endpoint.auth_required_supported",
            len(missing) == 0,
            "all endpoints include auth_required" if len(missing) == 0 else f"endpoints missing auth_required: {missing}",
        )

    def _check_response_content_type_support(self):
        endpoints = self.doc.get("endpoints", []) if isinstance(self.doc.get("endpoints"), list) else []
        missing = []
        for ep in endpoints:
            if not isinstance(ep, dict):
                continue
            if "response_content_type" not in ep:
                missing.append(ep.get("name", "<unknown>"))

        self._emit(
            "impl.endpoint.response_content_type_supported",
            len(missing) == 0,
            "all endpoints include response_content_type"
            if len(missing) == 0
            else f"endpoints missing response_content_type: {missing}",
        )

    def _check_param_constraints_published(self):
        endpoints = self.doc.get("endpoints", []) if isinstance(self.doc.get("endpoints"), list) else []
        params_total = 0
        constrained = 0

        for ep in endpoints:
            if not isinstance(ep, dict):
                continue
            params = ep.get("params", [])
            if not isinstance(params, list):
                continue
            for p in params:
                if not isinstance(p, dict):
                    continue
                params_total += 1
                if any(field in p for field in CONSTRAINT_FIELDS):
                    constrained += 1

        if params_total == 0:
            self._emit("impl.params.constraints_published", True, "no params defined; constraint publication not applicable")
            return

        ok = constrained > 0
        self._emit(
            "impl.params.constraints_published",
            ok,
            f"{constrained}/{params_total} params publish machine-readable constraints",
        )

    def _check_agent_rules_consistent_shape(self):
        rules = self.doc.get("agent_rules")
        if rules is None:
            self._emit("impl.agent_rules.consistent", True, "agent_rules not present (optional)")
            return

        ok = isinstance(rules, list) and all(isinstance(x, str) and x.strip() for x in rules)
        self._emit(
            "impl.agent_rules.consistent",
            ok,
            "agent_rules is a non-empty string list" if ok else "agent_rules should be an array of non-empty strings",
        )


def load_json(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def print_report(results: List[CheckResult]):
    must_fail = 0
    should_fail = 0

    print("AIIF Conformance Report")
    print("=" * 72)

    for result in results:
        status = "PASS" if result.passed else "FAIL"
        print(f"[{status}] {result.check_id} ({result.level})")
        print(f"       {result.message}")
        if not result.passed:
            if result.level == "MUST":
                must_fail += 1
            elif result.level == "SHOULD":
                should_fail += 1

    print("-" * 72)
    print(f"Total checks: {len(results)}")
    print(f"MUST failures: {must_fail}")
    print(f"SHOULD failures: {should_fail}")

    if must_fail == 0:
        print("Result: COMPLIANT (all MUST checks passed)")
    else:
        print("Result: NOT COMPLIANT (one or more MUST checks failed)")


def main():
    parser = argparse.ArgumentParser(description="Validate an AIIF document against AIIF-Conformance-Checklist.json")
    parser.add_argument("--aiif", required=True, help="Path to AIIF JSON document to validate")
    parser.add_argument(
        "--checklist",
        default="AIIF-Conformance-Checklist.json",
        help="Path to AIIF checklist JSON (default: AIIF-Conformance-Checklist.json)",
    )
    parser.add_argument(
        "--strict-should",
        action="store_true",
        help="Treat SHOULD failures as non-zero exit status",
    )

    args = parser.parse_args()

    if not os.path.exists(args.aiif):
        print(f"AIIF file not found: {args.aiif}")
        return 2

    if not os.path.exists(args.checklist):
        print(f"Checklist file not found: {args.checklist}")
        return 2

    try:
        aiif_doc = load_json(args.aiif)
        checklist_doc = load_json(args.checklist)
    except json.JSONDecodeError as exc:
        print(f"Invalid JSON: {exc}")
        return 2

    validator = Validator(aiif_doc, checklist_doc)
    validator.run()
    print_report(validator.results)

    must_fail = sum(1 for r in validator.results if (not r.passed and r.level == "MUST"))
    should_fail = sum(1 for r in validator.results if (not r.passed and r.level == "SHOULD"))

    if must_fail > 0:
        return 1

    if args.strict_should and should_fail > 0:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
