#!/usr/bin/env bash
# PostToolUse(Bash) hook — no-mistakes gate.
#
# Fires after every Bash call. When the call was a real task submission (an invocation of
# submit.sh), it feeds the running agent a directive to run the reviewer safety/quality gate
# before the change reaches human PR review. On any other Bash call it stays silent.
#
# The hook itself is a shell script and cannot run the LLM reviewer; it can only tell the
# agent to invoke it. So it emits a PostToolUse `block` decision whose `reason` is the
# directive Claude then acts on (spawn the `reviewer` subagent / run the /no-mistakes skill).
set -euo pipefail

input="$(cat)"

# Pull out the actual Bash command. We must inspect the *command*, not the whole JSON payload:
# a plain grep for "submit.sh" over the payload also matches commands that merely MENTION the
# string (a commit message, a `gh pr edit --body`, an echo), which would false-trigger the gate.
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
elif command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || true)"
else
  # No JSON parser available: fall back to the raw payload. Less precise, but the
  # command-position test below still rejects the common "mention" false positives.
  cmd="$input"
fi
[ -n "$cmd" ] || exit 0

# Fire only when submit.sh is actually being *invoked* — i.e. it is the executable at the start
# of some command segment — not when it appears as an argument (e.g. inside a quoted message).
# Split the command on shell separators (&&, ||, ;, |, newline) and check each segment's first
# token. This distinguishes `./submit.sh T-102` (invocation) from `git commit -m "...submit.sh"`.
is_submit=0
while IFS= read -r seg; do
  seg="${seg#"${seg%%[![:space:]]*}"}"   # strip leading whitespace
  seg="${seg#bash }"                      # unwrap an optional `bash `/`sh ` launcher
  seg="${seg#sh }"
  seg="${seg#"${seg%%[![:space:]]*}"}"
  tok="${seg%%[[:space:]]*}"              # first token of the segment
  case "$tok" in
    submit.sh|*/submit.sh) is_submit=1; break ;;
  esac
done <<EOF
$(printf '%s' "$cmd" | sed -E 's/&&|\|\|/\n/g; s/[;|]/\n/g')
EOF
[ "$is_submit" -eq 1 ] || exit 0

# Best-effort task id (first T-<n> in the command) for a targeted review.
id="$(printf '%s' "$cmd" | grep -oE 'T-[0-9]+' | head -1 || true)"
target="${id:-the current branch vs main}"

# If the captain has enabled auto-merge, add the low-risk fast-path directive.
auto_line=""
manifest="${CLAUDE_PROJECT_DIR:-.}/.helm-kit.json"
if [ -f "$manifest" ] && command -v python3 >/dev/null 2>&1; then
  enabled="$(python3 - "$manifest" <<'PY' 2>/dev/null || true
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for b in (d.get("preset", {}), d):
    am = b.get("auto_merge") if isinstance(b, dict) else None
    if isinstance(am, dict) and am.get("enabled") is True:
        print("true"); break
PY
)"
  if [ "$enabled" = "true" ]; then
    auto_line=" Auto-merge is ON: if the verdict is APPROVE or APPROVE WITH NITS AND the reviewer rates RISK low, run tasks/auto-approve.sh ${id:-the-task-id} low to merge and finalize; for any other verdict or risk tier, route to the captain for approve.sh."
  fi
fi

# Reason text is fed verbatim to Claude. Keep it free of " and \ so the JSON stays valid
# without an escaper (no external dependency for the output path).
msg="Task ${target} was just submitted for review. Before it goes to human PR approval, run the no-mistakes gate now: invoke the reviewer subagent (subagent_type reviewer) on ${target}, or run the /no-mistakes skill. Relay its verdict; if it is BLOCK or CHANGES REQUESTED, surface the findings and treat the task as NOT done until they are addressed.${auto_line}"

printf '{"decision":"block","reason":"%s"}\n' "$msg"
exit 0
