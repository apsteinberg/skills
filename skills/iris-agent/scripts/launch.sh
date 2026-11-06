#!/usr/bin/env bash
# Start an agent on a cluster compute node: tmux on the login node, interactive SLURM job
# inside it, agent (with Claude Remote Control) inside the job.
#
# launch.sh --name NAME --dir DIR [--task TEXT | --task-file FILE] [--agent claude|"<command>"]
#           [--mem 12G] [--time 48:00:00] [--perm MODE] [--trust] [--queue-wait SECONDS] [--no-view]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

NAME="" DIR="" TASK="" AGENT=claude MEM=12G TIME=48:00:00 PERM="" TRUST=no QUEUE_WAIT=600 VIEW=yes
while (( $# )); do
  case $1 in
    --name) NAME=$2; shift 2 ;;
    --dir) DIR=$2; shift 2 ;;
    --task) TASK=$2; shift 2 ;;
    --task-file) TASK=$(cat "$2"); shift 2 ;;
    --agent) AGENT=$2; shift 2 ;;
    --mem) MEM=$2; shift 2 ;;
    --time) TIME=$2; shift 2 ;;
    --perm) PERM=$2; shift 2 ;;
    --trust) TRUST=yes; shift ;;
    --queue-wait) QUEUE_WAIT=$2; shift 2 ;;
    --no-view) VIEW=no; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
[[ -n $NAME && -n $DIR ]] || { echo "need --name and --dir" >&2; exit 2; }

# "Log in": site settings and the connection come from config.sh.
source "$HERE/config.sh"
echo "[iris-agent] connecting via $VIA"

[[ $NAME =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,39}$ ]] || { echo "Error: --name must start with a letter or digit and use only letters, digits, - and _" >&2; exit 2; }

# The task goes over stdin, ahead of the script (base64 has no shell-special characters),
# so it never appears in a process list on either machine.
TASK_B64=$(printf '%s' "$TASK" | base64 | tr -d '\n')
set +e
{ printf 'TASK_B64=%s\n' "$TASK_B64"; cat "$HERE/remote.sh"; } \
  | remote_script "$NAME" "$DIR" "$MEM" "$TIME" "$AGENT" "$PERM" "$TRUST" "$QUEUE_WAIT" "$IRIS_JOB_SCRIPT" 2>&1 | grep -v 'acd_func'
rc=${PIPESTATUS[1]}
set -e

# A Herdr tab that shows the tmux session (closing it only detaches).
if [[ $VIEW == yes && $VIA == herdr && ( $rc == 0 || $rc == 3 || $rc == 5 ) ]] && command -v herdr-app >/dev/null; then
  herdr-app do space.new --machine "$IRIS_HOST" --name "$IRIS_HOST: $NAME" --argv "[\"tmux\",\"attach\",\"-t\",\"=$NAME\"]" >/dev/null \
    && echo "[iris-agent] opened Herdr space '$IRIS_HOST: $NAME' attached to the tmux session"
fi
exit "$rc"
