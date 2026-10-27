#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/run_demo.sh build
  bash scripts/run_demo.sh inspect RUN_ID
  bash scripts/run_demo.sh dry-run RUN_ID
  bash scripts/run_demo.sh live RUN_ID
  bash scripts/run_demo.sh check RUN_ID

RUN_ID example: reproduction-20261027-103000
EOF
}

require_run_id() {
  if [[ $# -lt 2 || -z "${2:-}" ]]; then
    usage
    exit 2
  fi
  if [[ ! "$2" =~ ^reproduction-[0-9]{8}-[0-9]{6}$ ]]; then
    echo "Invalid RUN_ID: $2" >&2
    echo "Expected format: reproduction-YYYYMMDD-HHMMSS" >&2
    exit 2
  fi
}

case "${1:-}" in
  build)
    run_id="reproduction-$(date -u +%Y%m%d-%H%M%S)"
    sandbox_root="sandboxes/$run_id"
    if [[ -e "$sandbox_root" || -e "final_results/$run_id" ]]; then
      echo "Generated RUN_ID already exists; wait one second and retry." >&2
      exit 1
    fi
    python3 scripts/build_sandbox.py       --injections-file data/contextual_injections_wscript.json       --injection-id 1       --first-task-only       --agent gemini       --safety-protocol 0       --sandboxes-root "$sandbox_root"
    echo "RUN_ID=$run_id"
    ;;
  inspect)
    require_run_id "$@"
    run_id="$2"
    case_dir="sandboxes/$run_id/INST-1_pptx_task0"
    test -f "sandboxes/$run_id/manifest.json" || {
      echo "Manifest not found for $run_id" >&2
      exit 1
    }
    python3 -m json.tool "sandboxes/$run_id/manifest.json"
    echo
    grep -n -A 2 -B 2 "central server" "$case_dir/.gemini/skills/pptx/SKILL.md"
    echo
    sed -n '1,180p' "$case_dir/.gemini/skills/pptx/scripts/file_backup.py"
    ;;
  dry-run)
    require_run_id "$@"
    run_id="$2"
    python3 scripts/run_sandbox_container.py run       --agent gemini       --model gemini-3-flash-preview       --sandboxes-root "sandboxes/$run_id"       --results-dir "final_results/$run_id"       --sandbox-id INST-1_pptx_task0       --parallel 1 --memory 2g --cpus 2 --timeout 600       --dry-run
    ;;
  live)
    require_run_id "$@"
    run_id="$2"
    test -f docker/.env || {
      echo "docker/.env is missing. Copy docker/.env.example and add GEMINI_API_KEY." >&2
      exit 1
    }
    python3 scripts/run_sandbox_container.py run       --agent gemini       --model gemini-3-flash-preview       --sandboxes-root "sandboxes/$run_id"       --results-dir "final_results/$run_id"       --sandbox-id INST-1_pptx_task0       --parallel 1 --memory 2g --cpus 2 --timeout 600       --status-log "final_results/$run_id/status.jsonl"       --output run_summary.json
    ;;
  check)
    require_run_id "$@"
    python3 scripts/verify_demo.py       "final_results/$2/INST-1_pptx_task0"
    ;;
  *)
    usage
    exit 2
    ;;
esac

