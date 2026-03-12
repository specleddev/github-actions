#!/usr/bin/env bash
set -euo pipefail

workspace="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
runner_temp="${RUNNER_TEMP:-$workspace/.tmp}"

escape_elixir_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

resolve_from_workspace() {
  local candidate="$1"

  if [[ "$candidate" == /* ]]; then
    printf '%s\n' "$candidate"
  else
    printf '%s\n' "$workspace/$candidate"
  fi
}

normalize_bool() {
  local lowered
  lowered="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"

  case "$lowered" in
    true|1|yes|on) printf 'true\n' ;;
    false|0|no|off) printf 'false\n' ;;
    *)
      echo "::error::Expected a boolean value, got: $1"
      exit 1
      ;;
  esac
}

target_root="$(resolve_from_workspace "${INPUT_ROOT:-.}")"
spec_dir="${INPUT_SPEC_DIR:-.spec}"
backend_repo="${INPUT_BACKEND_REPO:-specleddev/spec_led_ex}"
backend_ref="${INPUT_BACKEND_REF:-main}"
backend_path_input="${INPUT_BACKEND_PATH:-}"
run_commands="$(normalize_bool "${INPUT_RUN_COMMANDS:-true}")"
diffcheck="$(normalize_bool "${INPUT_DIFFCHECK:-false}")"
check_clean="$(normalize_bool "${INPUT_CHECK_CLEAN:-true}")"
min_strength="${INPUT_MIN_STRENGTH:-}"
diff_base="${INPUT_DIFF_BASE:-}"

if [[ ! -d "$target_root" ]]; then
  echo "::error::Target root does not exist: $target_root"
  exit 1
fi

target_root="$(cd "$target_root" && pwd)"
baseline_spec_status=""
track_cleanliness="false"

if [[ "$check_clean" == "true" ]] && git -C "$target_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  baseline_spec_status="$(git -C "$target_root" status --porcelain -- "$spec_dir")"
  track_cleanliness="true"
fi

if [[ -n "$backend_path_input" ]]; then
  backend_path="$(resolve_from_workspace "$backend_path_input")"

  if [[ ! -d "$backend_path" ]]; then
    echo "::error::Backend path does not exist: $backend_path"
    exit 1
  fi

  backend_path="$(cd "$backend_path" && pwd)"
  dependency="{:spec_led_ex, path: \"$(escape_elixir_string "$backend_path")\", runtime: false}"
  backend_source="path:$backend_path"
else
  dependency="{:spec_led_ex, github: \"$(escape_elixir_string "$backend_repo")\", ref: \"$(escape_elixir_string "$backend_ref")\", runtime: false}"
  backend_source="github:$backend_repo@$backend_ref"
fi

mkdir -p "$runner_temp"
runner_dir="$(mktemp -d "$runner_temp/specled-runner.XXXXXX")"
trap 'rm -rf "$runner_dir"' EXIT

cat > "$runner_dir/mix.exs" <<EOF
defmodule SpecLedRunner.MixProject do
  use Mix.Project

  def project do
    [
      app: :spec_led_runner,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: [
        $dependency
      ]
    ]
  end
end
EOF

echo "::group::Spec Led configuration"
echo "root=$target_root"
echo "spec_dir=$spec_dir"
echo "backend=$backend_source"
echo "run_commands=$run_commands"
echo "diffcheck=$diffcheck"
echo "check_clean=$check_clean"
if [[ -n "$min_strength" ]]; then
  echo "min_strength=$min_strength"
fi
if [[ -n "$diff_base" ]]; then
  echo "diff_base=$diff_base"
fi
echo "::endgroup::"

pushd "$runner_dir" >/dev/null

mix deps.get

check_command=(mix spec.check --root "$target_root" --spec-dir "$spec_dir")

if [[ "$run_commands" == "false" ]]; then
  check_command+=(--no-run-commands)
fi

if [[ -n "$min_strength" ]]; then
  check_command+=(--min-strength "$min_strength")
fi

"${check_command[@]}"

if [[ "$diffcheck" == "true" ]]; then
  diff_command=(mix spec.diffcheck --root "$target_root" --spec-dir "$spec_dir")

  if [[ -n "$diff_base" ]]; then
    diff_command+=(--base "$diff_base")
  fi

  "${diff_command[@]}"
fi

popd >/dev/null

if [[ "$check_clean" == "true" ]]; then
  if [[ "$track_cleanliness" == "true" ]]; then
    spec_changes="$(git -C "$target_root" status --porcelain -- "$spec_dir")"

    if [[ "$spec_changes" != "$baseline_spec_status" ]]; then
      echo "::error::Spec Led checks changed files under $spec_dir. Commit the updated spec artifacts before merging."
      printf '%s\n' "$spec_changes"
      exit 1
    fi
  else
    echo "::warning::Skipping spec workspace cleanliness check because $target_root is not in a Git work tree."
  fi
fi
