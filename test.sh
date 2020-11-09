#!/bin/bash

# strict mode
set -o errexit -o pipefail -o noclobber -o nounset
IFS=$'\n\t'

function error() { echo "$(tput setaf 1)$*$(tput sgr0)" >&2 && exit 1; }
function log() { echo "$(tput setaf 6)$*$(tput sgr0)"; }

# tap header
export ntap=1
export tap_total=21
echo "1..$tap_total"

# tap tests
function tap() {
	[[ $? -eq 0 ]] || echo -n "not "
	local description=$1 && shift
	echo "ok $ntap $(tput setaf 4)$description$(tput sgr0)"
	((ntap += 1))
}

export output
export code

function smash() {
	output=$(bash ./smash.sh "$@") && code=$?
	# debug
}

function debug() {
	echo "$output"
	log "==> state" && cat smash/engine/state
	log "==> plan" && cat smash/engine/plan
	log "==> end"
}

log "start with clean workspace"
rm -rf smash/engine target

[[ "$(wc -l ./smash.sh | awk '{ print $1 }')" -lt 200 ]]
tap "with a script of <200 lines" $?

[[ ! -d target ]]
tap "we start without ./target" $?

log "run ./smash.sh with no args"
smash

[[ $code -eq 0 ]]
tap "script exits with 0" $?

[[ "$(wc -l ./smash/engine/plan | awk '{ print $1 }')" -eq 3 ]]
tap "work was planned" $?

[[ $output =~ "==> run" && $output =~ "run smash/make_target/run" ]]
tap "one run script planned" $?

[[ $output =~ "==> test" && $output =~ "test smash/make_target/test" ]]
tap "one test script planned" $?

[[ $output =~ "! excute work" ]]
tap "work was done" $?

[[ $output =~ "==> done" ]]
tap "smash reports completing successfully" $?=true

[[ $(echo "$output" | wc -l | awk '{ print $1 }') -gt 20 ]]
tap "we log everything to the user" $?

[[ -d target && -f target/version ]]
tap "we now have the artifact ./target/version" $?

log "run ./smash.sh again"
smash

[[ $code -eq 0 ]]
tap "script exits with 0" $?

[[ "$(wc -l ./smash/engine/plan | awk '{ print $1 }')" -eq 1 ]]
tap "no work was planned" $?

[[ ! $output =~ "$ smash/make_target/run" ]]
tap "no work was done" $?

log "clear the workspace and do a dry run"
rm -rf smash/engine target
smash -n

[[ ! -d target ]]
tap "smash did not create ./target" $?

[[ $(echo "$output" | wc -l | awk '{ print $1 }') -gt 10 ]]
tap "we log everything to the user" $?

[[ $output =~ "==> run" && $output =~ "==> run" ]]
tap "both planned steps were dry run" $?

[[ $output =~ "==> done" ]]
tap "smash reports completing successfully" $?

log "run smash plan silently"
smash -s

[[ -d target && -f target/version ]]
tap "we have the artifact ./target/version" $?

[[ $(echo "$output" | wc -l | awk '{ print $1 }') -eq 1 ]]
tap "nothing gets logged to the user" $?

[[ $output =~ "==> done" ]]
tap "except that smash was successfully completed" $?

log "clean all test artifacts"
rm -rf smash/engine target

[[ $ntap -eq $tap_total ]]
tap "ran expected number of tests in ./test.sh" $?
