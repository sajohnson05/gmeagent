#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_FILE="$ROOT_DIR/claude.md"

CHECK_MODEL_ROUTING=false
QUIET=false

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

ERROR_COUNT=0
WARNING_COUNT=0
PASS_COUNT=0

print_usage() {
  cat <<'EOF'
Usage:
  ./validate-skills.sh [--check-model-routing] [--quiet] [--help]

Options:
  --check-model-routing   Validate model routing assumptions in claude.md
  --quiet                 Only print warnings/errors and final summary
  --help                  Show this help message
EOF
}

log_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  if [[ "$QUIET" != true ]]; then
    printf "${GREEN}PASS${NC}: %s\n" "$1"
  fi
}

log_warn() {
  WARNING_COUNT=$((WARNING_COUNT + 1))
  printf "${YELLOW}WARNING${NC}: %s\n" "$1"
}

log_error() {
  ERROR_COUNT=$((ERROR_COUNT + 1))
  printf "${RED}ERROR${NC}: %s\n" "$1"
}

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    log_error "Required file missing: $file"
    return 1
  fi
  log_pass "Found file: $file"
}

require_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    log_error "Required directory missing: $dir"
    return 1
  fi
  log_pass "Found directory: $dir"
}

require_contains() {
  local file="$1"
  local text="$2"
  local label="$3"

  if grep -Fq "$text" "$file"; then
    log_pass "$label"
  else
    log_error "$label"
  fi
}

warn_if_contains() {
  local file="$1"
  local text="$2"
  local label="$3"

  if grep -Fqi "$text" "$file"; then
    log_warn "$label"
  else
    log_pass "No unsafe wording detected for: $label"
  fi
}

section_exists() {
  local file="$1"
  local start="$2"
  local end="$3"

  awk -v start="$start" -v end="$end" '
    $0 ~ start { in_block=1; found=1; next }
    $0 ~ end && in_block { exit 0 }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

extract_section() {
  local file="$1"
  local start="$2"
  local end="$3"

  awk -v start="$start" -v end="$end" '
    $0 ~ start { in_block=1; next }
    $0 ~ end && in_block { exit }
    in_block { print }
  ' "$file"
}

validate_core_structure() {
  require_dir "$ROOT_DIR/agents"
  require_dir "$ROOT_DIR/skills"
  require_dir "$ROOT_DIR/context"
  require_dir "$ROOT_DIR/flows"
  require_dir "$ROOT_DIR/validation"

  require_file "$ROOT_DIR/README.md"
  require_file "$ROOT_DIR/.gitignore"
  require_file "$CLAUDE_FILE"

  require_contains "$CLAUDE_FILE" "<role>" "claude.md contains <role> block"
  require_contains "$CLAUDE_FILE" "<context_files>" "claude.md contains <context_files> block"
  require_contains "$CLAUDE_FILE" "<agent_team>" "claude.md contains <agent_team> block"
  require_contains "$CLAUDE_FILE" "<agent_roles>" "claude.md contains <agent_roles> block"
  require_contains "$CLAUDE_FILE" "<workflow>" "claude.md contains <workflow> block"
  require_contains "$CLAUDE_FILE" "<quality_checks>" "claude.md contains <quality_checks> block"
  require_contains "$CLAUDE_FILE" "<self_improvement_loop>" "claude.md contains <self_improvement_loop> block"
  require_contains "$CLAUDE_FILE" "<success_criteria>" "claude.md contains <success_criteria> block"
}

validate_model_routing() {
  echo
  echo "Running optional model routing checks..."

  if [[ ! -f "$CLAUDE_FILE" ]]; then
    log_error "Cannot run model routing checks because claude.md is missing"
    return
  fi

  require_contains "$CLAUDE_FILE" "<model_routing>" "claude.md contains <model_routing> block"
  require_contains "$CLAUDE_FILE" "High Complexity" "model routing defines High Complexity"
  require_contains "$CLAUDE_FILE" "Medium Complexity" "model routing defines Medium Complexity"
  require_contains "$CLAUDE_FILE" "Low Complexity" "model routing defines Low Complexity"
  require_contains "$CLAUDE_FILE" "default to Sonnet" "model routing defaults to Sonnet"
  require_contains "$CLAUDE_FILE" "escalate to Opus only when" "model routing includes escalation to Opus rule"
  require_contains "$CLAUDE_FILE" "use Haiku for validation" "model routing assigns Haiku to lightweight validation work"

  require_contains "$CLAUDE_FILE" "assess complexity level (low, medium, high)" "workflow triage includes complexity assessment"
  require_contains "$CLAUDE_FILE" "select model tier using <model_routing>" "workflow triage includes model tier selection"

  require_contains "$CLAUDE_FILE" "Use Opus for:" "model routing includes Opus examples"
  require_contains "$CLAUDE_FILE" "Use Sonnet for:" "model routing includes Sonnet examples"
  require_contains "$CLAUDE_FILE" "Use Haiku for:" "model routing includes Haiku examples"

  warn_if_contains "$CLAUDE_FILE" "automatically switches models" "claude.md implies automatic model switching"
  warn_if_contains "$CLAUDE_FILE" "Claude will automatically switch models" "claude.md claims unsupported automatic runtime model switching"

  local model_section
  model_section="$(extract_section "$CLAUDE_FILE" "<model_routing>" "</model_routing>")"

  if [[ -z "$model_section" ]]; then
    log_error "Unable to extract <model_routing> block from claude.md"
    return
  fi

  if echo "$model_section" | grep -A20 "Low Complexity" | grep -Eiq 'accreditation|medicare|legal|strategy|cross-functional|cross functional|financial risk'; then
    log_warn "Low Complexity block appears to reference high-risk work. Review Haiku suitability."
  else
    log_pass "Low Complexity block does not obviously assign high-risk work to Haiku"
  fi

  if echo "$model_section" | grep -A20 "High Complexity" | grep -Eiq 'strategic|accreditation|financial|cross-functional|cross functional|material risk'; then
    log_pass "High Complexity block includes appropriate high-risk reasoning indicators"
  else
    log_warn "High Complexity block may be too generic. Consider adding clearer high-risk reasoning indicators."
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check-model-routing)
        CHECK_MODEL_ROUTING=true
        shift
        ;;
      --quiet)
        QUIET=true
        shift
        ;;
      --help|-h)
        print_usage
        exit 0
        ;;
      *)
        log_error "Unknown argument: $1"
        print_usage
        exit 1
        ;;
    esac
  done

  echo "Validating repository structure..."
  validate_core_structure

  if [[ "$CHECK_MODEL_ROUTING" == true ]]; then
    validate_model_routing
  fi

  echo
  echo "Validation summary:"
  printf "  Passes:   %s\n" "$PASS_COUNT"
  printf "  Warnings: %s\n" "$WARNING_COUNT"
  printf "  Errors:   %s\n" "$ERROR_COUNT"

  if [[ "$ERROR_COUNT" -gt 0 ]]; then
    exit 1
  fi

  exit 0
}

main "$@"