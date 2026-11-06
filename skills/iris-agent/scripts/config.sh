#!/usr/bin/env bash
# Sourced by launch.sh and inbox.sh: loads site settings that stay out of this repo,
# and picks how to reach the cluster (Herdr's connection if it's up, else ssh).

CONFIG=${IRIS_AGENT_CONFIG:-$HOME/.config/iris-agent/config}
if [[ ! -f $CONFIG ]]; then
  cat >&2 <<EOF
Error: no config at $CONFIG. Create it (chmod 600) with:
  IRIS_HOST=<Herdr machine name or ssh alias of the login node>
  IRIS_JOB_SCRIPT=<path on the cluster to a script taking "<mem> <time>" that runs srun --pty ... bash>
EOF
  exit 2
fi
# shellcheck source=/dev/null
source "$CONFIG"
: "${IRIS_HOST:?set IRIS_HOST in $CONFIG}" "${IRIS_JOB_SCRIPT:?set IRIS_JOB_SCRIPT in $CONFIG}"

# remote_script ARGS...   run the script on stdin there, with ARGS as its $1, $2, ...
# on_iris 'SCRIPT' ARGS... run a fixed script there; values go in as $1, $2, ... never into the text.

# IRIS_HOST=local: this machine is the login node itself.
if [[ $IRIS_HOST == local ]]; then
  if [[ -n ${SLURM_JOB_ID:-} ]]; then
    echo "Error: inside SLURM job $SLURM_JOB_ID. Run this on the login node: tmux here would end with this job, and srun would start a step of it instead of a new job." >&2
    exit 2
  fi
  command -v squeue >/dev/null && command -v tmux >/dev/null || { echo "Error: IRIS_HOST=local needs squeue and tmux on this machine" >&2; exit 2; }
  VIA=local
  remote_script() { bash -s -- "$@"; }
  on_iris() { local s=$1; shift; bash -c "$s" iris-agent "$@" 2>&1 || true; }
  return 0 2>/dev/null || true
fi

HC_STATE=$(hc machine ls 2>/dev/null | grep -o "\"name\":\"$IRIS_HOST\"[^}]*" | grep -o '"state":"[a-z_]*"' | cut -d'"' -f4 || true)
if [[ -n $HC_STATE && $HC_STATE != connected ]]; then
  echo "Error: Herdr knows $IRIS_HOST but its connection is '$HC_STATE'. Reconnect with: hc machine login $IRIS_HOST" >&2
  exit 7
fi
if [[ $HC_STATE == connected ]]; then
  VIA=herdr
  remote_script() { hc exec --on "$IRIS_HOST" --timeout 600 -i -- bash -s -- "$@"; }
  on_iris() { local s=$1; shift; hc exec --on "$IRIS_HOST" --timeout 600 -- bash -c "$s" iris-agent "$@" 2>&1 | grep -v acd_func || true; }
else
  VIA=ssh
  remote_script() { ssh -o BatchMode=yes "$IRIS_HOST" bash -s -- "$(printf '%q ' "$@")"; }
  on_iris() { local s=$1; shift; ssh -o BatchMode=yes "$IRIS_HOST" "bash -c $(printf %q "$s") iris-agent $(printf '%q ' "$@")" 2>&1 | grep -v acd_func || true; }
fi
