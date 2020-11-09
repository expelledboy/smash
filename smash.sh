#!/usr/bin/env bash

# strict mode
set -o errexit -o pipefail -o noclobber -o nounset
IFS=$'\n\t'

if ! command -v tput >/dev/null; then
	tput() { :; }
	export -f tput
fi

USAGE=$(
	cat <<-EOF
		usage: smash [-anpst] [-o action,..]
		  -o Only run comma seperated list of actions.
		  -p Plan only; generate an execution plan. Can be approved in PR.
		  -a Apply only; ensure state has not changed, and execute plan.
		  -n Dry run; print the commands that would be executed, but do not execute them.
		  -s Silent operation; do not print to stdout as they are executed.
		  -t Output planned tests in tap format.
	EOF
)

export SMASH_DIR
export PLAN_DATE

function log() { echo "$(tput setaf 2)$*$(tput sgr0)" >&3; }
function log_cat() { cat "$(tput setaf 2)$1$(tput sgr0)" >&3; }
function error() { echo "$(tput setaf 1)$*$(tput sgr0)" >&2 && exit 1; }

function find_scripts() {
	local actions
	if [[ ${2:-} == "--filter" ]]; then
		actions=$RUN_ONLY
	else
		actions=$ACTIONS
	fi
	for action in $actions; do
		find "smash/$action/$1" 2>/dev/null
	done
}

function load_state() {
	eval "$(
		awk -F= -v script="$(dirname "$1")/state" \
			'$1==script { print "export "$2"="$3 }' \
			"$STATE"
		awk -F= '{
			n=split($1,script,"/");
			if(script[n] == "state")
			print "export "toupper(script[n-1])"_"$2"="$3
		}' "$STATE"
	)"
}

function create_state() {
	touch "$STATE" && ln -sf "$STATE" "$SMASH_DIR/engine/state"
	for script in $(find_scripts state); do
		(
			log "$ $script"
			output=$($script)
			echo "$output" 1>&3
			echo "$output" |
				awk -v script="$script" '/[A-Z_]*=/ { print script "=" $0 }' |
				tee -a "$STATE" 1>/dev/null
		)
	done
}

function create_plan() {
	touch "$PLAN" && ln -sf "$PLAN" "$SMASH_DIR/engine/plan"
	echo "plan=$PLAN_DATE" >>"$PLAN"

	for script in $(find_scripts plan --filter); do
		(
			log "$ $script"
			load_state "$script"
			output=$($script)
			echo "$output" 1>&3
			echo "$output" |
				sed -nE "s!((post|pre)?-?(run|test|setup)) (.*)!$script=\\1=\4!p" |
				tee -a "$PLAN" 1>/dev/null
		)
	done
}

function run_step() {
	local step=$1
	(
		[[ "$step" == "test" ]] && tap_header && test_count=0
		IFS=" " && awk -F= -v phase="$step" '{
			n=split($1,script,"/");
			if (script[n]=="plan" && $2==phase)
			print script[n-1],$3
		}' "$PLAN" | while read -r plan script; do
			test -n "${called:-}" || log "==> $step" && called=true
			log "$ $script"
			[[ -z "${DRYRUN:-}" ]] || continue
			load_state "$script"
			if [[ "$step" == "test" ]]; then
				((test_count += 1))
				eval "$script" 1>&3 || { errexit=9 && echo -n "not " 1>&4; }
				echo "ok $test_count $plan" 1>&4
				[[ -z "${errexit:-}" ]] || exit "$errexit"
			else
				eval "$script" 1>&3 || error "-fatal"
			fi
		done
	)
}

function tap_header() {
	echo "1..$(awk '
		  /plan=test=/ { count++ } END { print count }
		' "$PLAN")" >&4
}

function filter_actions() {
	RUN_ONLY=""
	for action in $(echo "$1" | tr -d ' ' | tr ',' '\n'); do
		[[ -x $SMASH_DIR/$action/plan ]] ||
			error "-error ./smash/$action/plan not found"
		RUN_ONLY+=$(printf "%s\t\n" "$action")
	done
}

# find smash
while [[ ! -d $PWD/smash ]]; do
	[[ ! $PWD == "/" ]] || error "-error failed to find smash directory"
	cd ..
done

# define state and plan files
SMASH_DIR=$PWD/smash
PLAN_DATE=$(date +%s)
mkdir -p "$SMASH_DIR/engine"
STATE="$SMASH_DIR/engine/state.$PLAN_DATE"
PLAN="$SMASH_DIR/engine/plan.$PLAN_DATE"
ACTIONS=$(ls "$SMASH_DIR" | grep -vE 'undo_|engine|scripts')
RUN_ONLY=$ACTIONS

# ensure no state conflicts
while [[ -f $STATE ]]; do
	((PLAN_DATE += 1))
	STATE="$SMASH_DIR/engine/state.$PLAN_DATE"
	PLAN="$SMASH_DIR/engine/plan.$PLAN_DATE"
done

# parse args
while getopts "nspato:" ARG; do
	case "${ARG}" in
	n) DRYRUN=true ;;
	s) SILENT=true ;;
	p) PLAN_ONLY=true ;;
	a) APPLY_ONLY=true ;;
	t) TAP_TEST=true ;;
	o) filter_actions "$OPTARG" ;;
	*) error "$USAGE" ;;
	esac
done
shift $((OPTIND - 1))

# setup various fifos 3 log 4 tap
if [[ -z "${TAP_TEST:-}" ]]; then exec 4>/dev/null; else exec 4>&1; fi
if [[ -z "${SILENT:-}" ]]; then exec 3>&1; else exec 3>/dev/null; fi

# install global util scripts
PATH=$SMASH_DIR/scripts:$PATH

# find reality
log "==> init" && create_state

# plan
if [[ -z "${APPLY_ONLY:-}" ]]; then
	log "==> plan" && create_plan
else
	PLAN_DATE=$(awk -F= '$1=="plan" { print $2 }' "$SMASH_DIR/engine/plan")
	PLAN="$SMASH_DIR/engine/plan.$PLAN_DATE"
fi

[[ -z "${PLAN_ONLY:-}" ]] || { exec 3>&1 && log "==> ready" && exit; }

# verify state
if ! diff "$STATE" "$SMASH_DIR/engine/state.$PLAN_DATE"; then
	error "-fatal inconsistent state"
fi

# apply
for phase in setup run test; do
	for hook in pre- "" post-; do
		run_step $hook$phase
	done
done

exec 3>&1 && log "==> done"
