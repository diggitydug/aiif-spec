#!/usr/bin/env bash
set -euo pipefail

AIIF=""
CHECKLIST="AIIF-Conformance-Checklist.json"
STRICT_SHOULD="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aiif)
      AIIF="${2:-}"
      shift 2
      ;;
    --checklist)
      CHECKLIST="${2:-}"
      shift 2
      ;;
    --strict-should)
      STRICT_SHOULD="true"
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./tools/validate-aiif.sh --aiif <path> [--checklist <path>] [--strict-should]

Options:
  --aiif <path>        Path to AIIF JSON document (required)
  --checklist <path>   Path to checklist JSON (default: AIIF-Conformance-Checklist.json)
  --strict-should      Treat SHOULD failures as non-compliant
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$AIIF" ]]; then
  echo "Missing required argument: --aiif <path>" >&2
  exit 2
fi

if [[ ! -f "$AIIF" ]]; then
  echo "AIIF file not found: $AIIF" >&2
  exit 2
fi

if [[ ! -f "$CHECKLIST" ]]; then
  echo "Checklist file not found: $CHECKLIST" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for validate-aiif.sh. Install jq and retry." >&2
  exit 2
fi

if ! jq empty "$AIIF" >/dev/null 2>&1; then
  echo "Invalid JSON in AIIF file: $AIIF" >&2
  exit 2
fi

if ! jq empty "$CHECKLIST" >/dev/null 2>&1; then
  echo "Invalid JSON in checklist file: $CHECKLIST" >&2
  exit 2
fi

get_level() {
  local cid="$1"
  jq -r --arg id "$cid" '.checks[]? | select(.id == $id) | .level // "INFO"' "$CHECKLIST" | head -n1
}

TOTAL=0
MUST_FAIL=0
SHOULD_FAIL=0

emit_result() {
  local cid="$1"
  local passed="$2"
  local msg="$3"
  local lvl
  lvl="$(get_level "$cid")"
  if [[ -z "$lvl" ]]; then lvl="INFO"; fi

  TOTAL=$((TOTAL + 1))
  if [[ "$passed" == "1" ]]; then
    echo "[PASS] $cid ($lvl)"
    echo "       $msg"
  else
    echo "[FAIL] $cid ($lvl)"
    echo "       $msg"
    if [[ "$lvl" == "MUST" ]]; then
      MUST_FAIL=$((MUST_FAIL + 1))
    elif [[ "$lvl" == "SHOULD" ]]; then
      SHOULD_FAIL=$((SHOULD_FAIL + 1))
    fi
  fi
}

echo "AIIF Conformance Report"
printf '=%.0s' {1..72}
echo

# impl.top_level.required_fields
if jq -e 'has("aiif_version") and (.aiif_version|type=="string") and ((.aiif_version|gsub("^\\s+|\\s+$";""))|length>0) and has("info") and has("endpoints") and (.info|type=="object") and (.endpoints|type=="array")' "$AIIF" >/dev/null; then
  emit_result "impl.top_level.required_fields" 1 "top-level required fields present"
else
  emit_result "impl.top_level.required_fields" 0 "missing/invalid top-level fields (requires non-empty string aiif_version, info object, endpoints array)"
fi

# impl.endpoint_name.unique
dup_names="$(jq -r '.endpoints[]? | .name // empty' "$AIIF" | sort | uniq -d | tr '\n' ',' | sed 's/,$//')"
if [[ -z "$dup_names" ]]; then
  emit_result "impl.endpoint_name.unique" 1 "endpoint names are unique"
else
  emit_result "impl.endpoint_name.unique" 0 "duplicate endpoint names: $dup_names"
fi

# impl.method_path.unique
dup_method_paths="$(jq -r '.endpoints[]? | select((.method//"") != "" and (.path//"") != "") | "\(.method)|\(.path)"' "$AIIF" | sort | uniq -d | tr '\n' ',' | sed 's/,$//')"
if [[ -z "$dup_method_paths" ]]; then
  emit_result "impl.method_path.unique" 1 "(method,path) pairs are unique"
else
  emit_result "impl.method_path.unique" 0 "duplicate (method,path) pairs: $dup_method_paths"
fi

# impl.params.unique_by_name_location
dup_params="$(jq -r '.endpoints[]? as $ep | ($ep.name // "<unknown>") as $n | ($ep.params // [])[]? | "\($n):\(.name // "<unknown>")|\(.location // "<unknown>")"' "$AIIF" | sort | uniq -d | tr '\n' ',' | sed 's/,$//')"
if [[ -z "$dup_params" ]]; then
  emit_result "impl.params.unique_by_name_location" 1 "params are unique by (name,location)"
else
  emit_result "impl.params.unique_by_name_location" 0 "duplicate params: $dup_params"
fi

# impl.auth_flow.structured_fields
if jq -e '.auth? and ((.auth.type == "bearer") or (.auth.type == "oauth2"))' "$AIIF" >/dev/null; then
  if jq -e '(.auth.instructions|type=="array" and length>0) and (.auth.acquire|type=="object") and (.auth.apply|type=="object")' "$AIIF" >/dev/null; then
    emit_result "impl.auth_flow.structured_fields" 1 "bearer/oauth2 auth includes instructions+acquire+apply"
  else
    emit_result "impl.auth_flow.structured_fields" 0 "bearer/oauth2 auth should include instructions, acquire, and apply"
  fi
else
  emit_result "impl.auth_flow.structured_fields" 1 "auth requirements not triggered"
fi

# impl.auth_docs.required_for_protected (static)
if jq -e '.auth? and (.auth.type // "") != "" and (.auth.type != "none")' "$AIIF" >/dev/null; then
  emit_result "impl.auth_docs.required_for_protected" 1 "requires /ai-docs/auth for protected APIs (runtime endpoint verification out of scope for static document validation)"
else
  emit_result "impl.auth_docs.required_for_protected" 1 "auth.type is none or missing; /ai-docs/auth requirement not triggered"
fi

# impl.endpoint.auth_required_supported
missing_auth_required="$(jq -r '.endpoints[]? | select(has("auth_required") | not) | (.name // "<unknown>")' "$AIIF" | tr '\n' ',' | sed 's/,$//')"
if [[ -z "$missing_auth_required" ]]; then
  emit_result "impl.endpoint.auth_required_supported" 1 "all endpoints include auth_required"
else
  emit_result "impl.endpoint.auth_required_supported" 0 "endpoints missing auth_required: $missing_auth_required"
fi

# impl.endpoint.response_content_type_supported
missing_response_ct="$(jq -r '.endpoints[]? | select(has("response_content_type") | not) | (.name // "<unknown>")' "$AIIF" | tr '\n' ',' | sed 's/,$//')"
if [[ -z "$missing_response_ct" ]]; then
  emit_result "impl.endpoint.response_content_type_supported" 1 "all endpoints include response_content_type"
else
  emit_result "impl.endpoint.response_content_type_supported" 0 "endpoints missing response_content_type: $missing_response_ct"
fi

# impl.params.constraints_published
params_total="$(jq -r '[.endpoints[]?.params[]?] | length' "$AIIF")"
constrained="$(jq -r '[.endpoints[]?.params[]? | select(has("minimum") or has("maximum") or has("min_length") or has("max_length") or has("pattern") or has("format"))] | length' "$AIIF")"
if [[ "$params_total" == "0" ]]; then
  emit_result "impl.params.constraints_published" 1 "no params defined; constraint publication not applicable"
else
  if (( constrained > 0 )); then
    emit_result "impl.params.constraints_published" 1 "$constrained/$params_total params publish machine-readable constraints"
  else
    emit_result "impl.params.constraints_published" 0 "$constrained/$params_total params publish machine-readable constraints"
  fi
fi

# impl.agent_rules.consistent
if jq -e 'has("agent_rules") | not' "$AIIF" >/dev/null; then
  emit_result "impl.agent_rules.consistent" 1 "agent_rules not present (optional)"
else
  if jq -e '.agent_rules | type == "array" and all(.[]?; type == "string" and (gsub("^\\s+|\\s+$";"") | length) > 0)' "$AIIF" >/dev/null; then
    emit_result "impl.agent_rules.consistent" 1 "agent_rules is a non-empty string list"
  else
    emit_result "impl.agent_rules.consistent" 0 "agent_rules should be an array of non-empty strings"
  fi
fi

printf -- '-%.0s' {1..72}
echo
echo "Total checks: $TOTAL"
echo "MUST failures: $MUST_FAIL"
echo "SHOULD failures: $SHOULD_FAIL"

if [[ "$MUST_FAIL" -eq 0 ]]; then
  echo "Result: COMPLIANT (all MUST checks passed)"
else
  echo "Result: NOT COMPLIANT (one or more MUST checks failed)"
fi

if [[ "$MUST_FAIL" -gt 0 ]]; then
  exit 1
fi

if [[ "$STRICT_SHOULD" == "true" && "$SHOULD_FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
