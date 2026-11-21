#!/usr/bin/env bash
set -euo pipefail

# NOTE: This is a dev-only script, intended for use by maintainers of this repo.
# It is not a supported installer. Modifications to it, or requests for
# modifications, will not be approved.
#
# Links all skills in the repository into skills directories used by agent
# harnesses. By default these are:
#   - ~/.claude/skills: Claude Code
#   - ~/.agents/skills: Codex and other Agent Skills-compatible harnesses
# Pass --dest (repeatable) to link into specific directories instead, e.g.
# ~/.copilot/skills for Copilot.
# Each entry is a symlink into this repo, so a `git pull` is all that's needed
# to keep installed skills up to date.

REPO="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<EOF
Usage: ${0##*/} [--dest DIR]... [-h|--help]

Creates one symlink per skill: DIR/<skill-name> --> $REPO/skills/.../<skill-name>.

Options:
  --dest DIR   Skills directory to link into. Repeat to link into several.
               Default: ~/.claude/skills and ~/.agents/skills.
               For Copilot use: ~/.copilot/skills.
  -h, --help   Show this help.

Examples:
  ${0##*/}
  ${0##*/} --dest ~/.copilot/skills
EOF
  exit 1
}

require_value() {
  local flag="$1" value="${2-}"
  if [ -z "$value" ] || [[ "$value" == --* ]]; then
    echo "error: $flag requires a value" >&2
    usage
  fi
}

DESTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dest)    require_value "$1" "${2-}"; DESTS+=("$2"); shift 2 ;;
    -h|--help) usage ;;
    *) echo "error: unknown option: $1" >&2; usage ;;
  esac
done

if [ ${#DESTS[@]} -eq 0 ]; then
  DESTS=("$HOME/.claude/skills" "$HOME/.agents/skills")
fi

# Collect the repo's skills once, link into every destination. `deprecated/`
# is retired, and `misc/` is kept around but rarely used and not promoted (see
# each bucket's own README): neither belongs in a daily-driver skill
# directory, so both are skipped here, same as everywhere else non-promoted
# skills are kept out. `in-progress/` IS still linked: it's public on purpose,
# feedback wanted, and this local install is exactly where that feedback loop
# runs.
names=()
srcs=()
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  names+=("$(basename "$src")")
  srcs+=("$src")
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' -not -path '*/misc/*' -print0)

for DEST in "${DESTS[@]}"; do
  # If $DEST is a symlink that resolves into this repo, we'd end up writing the
  # per-skill symlinks back into the repo's own skills/ tree. Detect and bail
  # out instead of polluting the working copy.
  if [ -L "$DEST" ]; then
    resolved="$(readlink -f "$DEST")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "error: $DEST is a symlink into this repo ($resolved)." >&2
        echo "Remove it (rm \"$DEST\") and re-run; the script will recreate it as a real dir." >&2
        exit 1
        ;;
    esac
  fi

  mkdir -p "$DEST"

  for i in "${!names[@]}"; do
    name="${names[$i]}"
    src="${srcs[$i]}"
    target="$DEST/$name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      rm -rf "$target"
    fi

    ln -sfn "$src" "$target"
    echo "linked $name -> $src ($DEST)"
  done
done
