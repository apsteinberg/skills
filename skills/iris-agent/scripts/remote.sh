#!/usr/bin/env bash
# Runs ON the cluster login node (sent over `hc exec -i` or `ssh`). Starts a tmux session, requests an
# interactive job inside it, and launches the agent on the compute node once the job runs.
# Usage: TASK_B64=<base64 task> remote.sh NAME DIR MEM TIME AGENT PERM TRUST QUEUE_WAIT JOB_SCRIPT
# launch.sh puts the TASK_B64 assignment in front of this script on stdin, so the task never
# shows in a process list.
set -euo pipefail
umask 077

NAME=$1 DIR=$2 MEM=$3 TIME=$4 AGENT=$5 PERM=$6 TRUST=$7 QUEUE_WAIT=$8 JOB_SCRIPT=${9:?job script path}
TASK_B64=${TASK_B64:-}
STATE=$HOME/.iris-agents

say() { echo "[iris-agent] $*"; }
die() { echo "[iris-agent] ERROR: $*" >&2; exit "${2:-1}"; }

# ---- check every input before it's used anywhere (arithmetic included) ----
[[ $NAME =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,39}$ ]] || die "name must start with a letter or digit and use only letters, digits, - and _ (max 40)"
[[ $MEM =~ ^[0-9]{1,6}[GgMm]$ ]] || die "memory must look like 8G or 4000M, got $MEM"
[[ $TIME =~ ^([0-9]{1,2}-)?[0-9]{1,3}(:[0-9]{1,2}){0,2}$ ]] || die "time must look like 48:00:00, 2:00:00 or 1-00:00:00, got $TIME"
[[ $QUEUE_WAIT =~ ^[0-9]{1,6}$ ]] || die "queue wait must be a whole number of seconds"
[[ $TRUST == yes || $TRUST == no ]] || die "trust must be yes or no"
case $PERM in "" | default | acceptEdits | auto | plan | bypassPermissions | dontAsk) ;; *) die "unknown permission mode $PERM" ;; esac

mem_mb=${MEM%?}; [[ ${MEM: -1} == [Gg] ]] && mem_mb=$(( 10#$mem_mb * 1024 ))
t=$TIME d=0; [[ $t == *-* ]] && { d=${t%%-*}; t=${t#*-}; }
IFS=: read -r h m s <<<"$t"
secs=$(( 10#$d*86400 + 10#${h:-0}*3600 + 10#${m:-0}*60 + 10#${s:-0} ))
(( 10#$mem_mb <= 12288 )) || die "memory $MEM is over the 12G cap"
(( secs <= 48*3600 )) || die "time $TIME is over the 48:00:00 cap"

DIR=${DIR/#\~/$HOME}
[[ -d $DIR ]] || die "folder $DIR does not exist on the cluster"
tmux has-session -t "=$NAME" 2>/dev/null && die "tmux session '$NAME' already exists (attach: tmux attach -t $NAME)" 4

# ---- this agent's own folder: its report helper and outbox, nothing else ----
BOX=$STATE/box/$NAME
[[ -d $BOX ]] && { chmod 700 "$BOX"; rm -rf "$BOX"; }
mkdir -p "$BOX"
chmod 700 "$STATE" "$STATE/box" "$BOX"
cat > "$BOX/report" <<'REPORT'
#!/usr/bin/env bash
# report <DONE|BLOCKED|QUESTION|UPDATE> <message...>  (appends one line to this agent's outbox)
kind=${1^^}; shift || true
case $kind in DONE|BLOCKED|QUESTION|UPDATE) ;; *) echo "usage: report DONE|BLOCKED|QUESTION|UPDATE <message>" >&2; exit 2;; esac
msg=$(printf '%s ' "$@" | tr -d '\000-\037\177' | cut -c1-500)
printf '%s %s %s\n' "$(date '+%F %T')" "$kind" "$msg" >> "$(dirname "$0")/outbox"
echo "reported $kind"
REPORT
: > "$BOX/outbox"
# The helper is pre-approved, so the agent must not be able to change it: read-only helper and
# folder (an agent allowed to edit files could otherwise turn it into any command). Appending
# to the outbox only needs write permission on that one file.
chmod 600 "$BOX/outbox"; chmod 500 "$BOX/report" "$BOX"

# ---- the task (pasted once the agent is up) and the launch line for the compute node ----
TASKF=$STATE/$NAME.task
# Control characters out (tab and newline stay): an ESC could end the bracketed paste early.
printf %s "$TASK_B64" | base64 -d | tr -d '\000-\010\013-\037\177' > "$TASKF"
if [[ -s $TASKF ]]; then
  { printf 'Task:\n'; cat "$TASKF"; cat <<NOTE


(Reporting: you are running unattended on a cluster compute node. When you finish, are blocked, or need a decision from the user, run \`$BOX/report DONE|BLOCKED|QUESTION|UPDATE "<one-line message>"\`, then wait at your prompt for an answer if you asked something. Use UPDATE sparingly, for major milestones. The report command is pre-approved; there's no need to read it.)
NOTE
  } > "$TASKF.full"
  mv "$TASKF.full" "$TASKF"
fi

case $AGENT in
  claude)  CMD=(claude "--remote-control=$NAME" "--allowedTools=Bash($BOX/report:*),Read(/$BOX/**)")
           [[ -n $PERM && $PERM != default ]] && CMD+=("--permission-mode=$PERM") ;;
  copilot) CMD=(copilot -n "$NAME" --add-dir "$BOX" --allow-tool "shell($BOX/report:*)")
           case $PERM in
             "" | default) ;;
             acceptEdits) CMD+=(--allow-tool write) ;;
             auto | bypassPermissions | dontAsk) CMD+=(--allow-all-tools) ;;
             plan) CMD+=(--plan) ;;
           esac ;;
  *)       read -r -a CMD <<<"$AGENT" ;;
esac
{
  echo "#!/usr/bin/env bash"
  echo "cd $(printf %q "$DIR") || exit 1"
  echo "echo \"[iris-agent] $NAME on \$(hostname) in job \$SLURM_JOB_ID\""
  printf 'exec %s\n' "$(printf '%q ' "${CMD[@]}")"
} > "$STATE/$NAME.sh"
chmod 700 "$STATE/$NAME.sh"

# ---- tmux + interactive job ----
before=$(squeue -u "$USER" -h -o %i | sort)
tmux new-session -d -s "$NAME" -x 200 -y 50 -c "$DIR"
tmux send-keys -t "=$NAME:" -l "bash $(printf '%q %q %q' "$JOB_SCRIPT" "$MEM" "$TIME")"
tmux send-keys -t "=$NAME:" Enter
say "tmux session '$NAME' started; requested $MEM for $TIME"

JOB=""
for _ in $(seq 1 30); do
  JOB=$(comm -13 <(echo "$before") <(squeue -u "$USER" -h -o %i | sort) | tail -1)
  [[ -n $JOB ]] && break; sleep 1
done
[[ $JOB =~ ^[0-9_]+$ ]] || die "no new SLURM job appeared; see: tmux capture-pane -pt $NAME"
echo "$JOB" > "$STATE/$NAME.job"
say "job $JOB submitted"

START="bash $(printf %q "$STATE/$NAME.sh")"
waited=0
while :; do
  st=$(squeue -j "$JOB" -h -o "%T %N" 2>/dev/null || true)
  [[ $st == RUNNING* ]] && break
  [[ -z $st ]] && die "job $JOB ended before it started; see: tmux capture-pane -pt $NAME"
  if (( waited >= 10#$QUEUE_WAIT )); then
    say "job $JOB still ${st%% *} after ${QUEUE_WAIT}s. When it runs, start the agent with:"
    say "  tmux send-keys -t $NAME '$START' Enter"
    say "and then paste the task from $TASKF (tmux load-buffer + paste-buffer -p)."
    exit 5
  fi
  sleep 5; waited=$((waited+5))
done
NODE=${st#* }
echo "$NODE" > "$STATE/$NAME.node"
say "job $JOB running on $NODE"

# The srun pty needs a moment before the node's shell reads input.
for _ in $(seq 1 20); do
  tmux capture-pane -pt "=$NAME:" | grep -qF "${NODE%%.*}" && break; sleep 1
done
sleep 2
tmux send-keys -t "=$NAME:" -l "$START"
tmux send-keys -t "=$NAME:" Enter

# ---- watch the agent come up; answer only its startup trust dialog ----
case $AGENT in
  claude)  TRUST_TEXT="Yes, I trust this folder" ;;
  copilot) TRUST_TEXT="Do you trust the files in this folder" ;;
  *)       TRUST_TEXT="" ;;
esac
LINK='https://claude\.ai/code/session_[A-Za-z0-9]+'
READY="" steady=0 asked=no
for _ in $(seq 1 45); do
  screen=$(tmux capture-pane -pt "=$NAME:")
  if [[ -n $TRUST_TEXT && $asked == no ]] && grep -qF "$TRUST_TEXT" <<<"$screen"; then
    [[ $TRUST == yes ]] || { say "$AGENT is asking whether to trust $DIR. Not answered (no --trust)."; exit 3; }
    # Claude's first choice is "No, exit"; Copilot's is "Yes".
    [[ $AGENT == claude ]] && { tmux send-keys -t "=$NAME:" Down; sleep 0.3; }
    tmux send-keys -t "=$NAME:" Enter
    asked=yes; say "trusted $DIR"; sleep 3; continue
  fi
  # Back at the node's shell prompt after the launch line: the agent exited.
  if sed -n "/\[iris-agent\] $NAME on/,\$p" <<<"$screen" | grep -v '^\s*$' | tail -1 | grep -qE '\$ *$'; then
    say "the agent exited right after starting:"
    sed -n "/\[iris-agent\] $NAME on/,\$p" <<<"$screen" | grep -v '^\s*$' | tail -8
    say "the job is still running; fix the problem, then: tmux send-keys -t $NAME '$START' Enter"
    exit 6
  fi
  case $AGENT in
    claude)  if grep -qE "$LINK" <<<"$(tmux capture-pane -J -pt "=$NAME:")" && grep -q "❯" <<<"$screen"; then
               url=$(tmux capture-pane -J -pt "=$NAME:" | grep -oE "$LINK" | head -1 || true)
               [[ -n $url ]] && echo "$url" > "$STATE/$NAME.url"
               say "remote control is on: ${url:-look for '$NAME' at claude.ai/code}"
               READY=yes
             fi ;;
    # Copilot's full-screen UI hides the launch line, so its own prompt is the sign.
    copilot) grep -q "❯" <<<"$screen" && (( ++steady >= 3 )) && READY=yes ;;
    *)       grep -qF "[iris-agent] $NAME on" <<<"$screen" && (( ++steady >= 3 )) && READY=yes ;;
  esac
  [[ $READY == yes ]] && break
  sleep 2
done

if [[ $READY != yes ]]; then
  say "WARNING: could not confirm the agent is up; check: tmux capture-pane -pt $NAME"
  [[ -s $TASKF ]] && say "task NOT sent; it's in $TASKF"
elif [[ -s $TASKF && ( $AGENT == claude || $AGENT == copilot ) ]]; then
  # Bracketed paste (-p): the task arrives as one block, so newlines don't submit it in pieces
  # and a leading "!" isn't taken as a shell escape.
  sleep 2
  tmux load-buffer -b "ia-$NAME" "$TASKF"
  tmux paste-buffer -p -d -b "ia-$NAME" -t "=$NAME:"
  sleep 1; tmux send-keys -t "=$NAME:" Enter
  rm -f "$TASKF"
  say "task sent"
fi

say "ready: $NAME | job $JOB on $NODE | $MEM for $TIME"
say "attach: tmux attach -t $NAME   (on the login node)"
echo "---SCREEN---"
tmux capture-pane -pt "=$NAME:" | grep -v '^\s*$' | tail -15
