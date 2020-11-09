# Smash

> Change the state of the universe, from &lt;200 lines of bash!

## Introduction

I liked `terraform`, but I wanted to be evil and use the full power of bash.

```
usage: smash [-anpst] [-o action,..]
  -o Only run comma seperated list of actions.
  -p Plan only; generate an execution plan. Can be approved in PR.
  -a Apply only; ensure state has not changed, and execute plan.
  -n Dry run; print the commands that would be executed, but do not execute them.
  -s Silent operation; do not print to stdout as they are executed.
  -t Output planned tests in tap format.
```

Creating a simple smash action to install your dotfiles!

```sh
# You will need a script which does the work
echo 'git clone https://github.com/username/dotfiles.git ~/.dotfiles' > install.sh
# And two action scripts with used by smash
mkdir -p smash/install_mac && pushd $_
echo '#!/bin/bash' > state
echo '#!/bin/bash' > plan
# One must determine the state of the machine
echo 'echo DOTFILES_INSTALLED=$(test -d ~/.dotfiles && echo true)' >> state
# They other uses that context to determine if anything must be done.
echo 'test "$DOTFILES_INSTALLED" != "true" && echo run bash ./install.sh' >> plan
# You could optionally add unit tests
echo 'echo test [[ -d ~/.dotfiles ]] || exit 1' >> plan
# Finally we set all our scripts to be executable.
popd && chmod +x ./smash/install_mac/* ./install.sh
# Test your action with a dry run first.
smash -n
# Create a plan, and then execute it.
smash -p
smash -a
ls ~/.dotfiles
# Or dont be a Becky...
rm -rf ~/.dotfiles
smash
ls ~/.dotfiles
```

```
$ smash
==> init
$ smash/install_mac/state
DOTFILES_INSTALLED=
==> plan
$ smash/install_mac/plan
run bash ./install.sh
test [[ -d /Users/anthony/.dotfiles ]]
==> run
$ bash ./install.sh
git clone https://github.com/username/dotfiles.git /Users/anthony/.dotfiles
==> test
$ [[ -d /Users/anthony/.dotfiles ]]
==> done

$ echo $? # winning
0
```

And you can write these scripts in any language your heart desired!

## Guide

- Your actions must be directories installed in `./smash/<action>`
  - A smash action needs only one file `./smash/<action>/plan`
  - Actions can contribute to state in `./smash/<action>/state`
  - By default all actions run under `./smash` unless you use the `-o` option
  - Actions prefixed with `undo_` are always ignored and must use `-o`
- State is ENV vars printed to stdout by the state script in `.env` format
  - eg. `MY_VAR=useful_info`
- These environment variables will be available in all phases of smash
- There are quite afew phases of smash;
  - state
  - plan
  - setup
  - run
  - test
- You can hook into `setup`, `run` and `test`
- There are also pre and post hooks eg. `pre-plan` .. `plan` .. `post-plan`
- You install a hook by printing to stdout in the plan script `<hook> cmd args`
- You can create global util scripts in `./smash/scripts/*`
- You can commit `./smash/engine/*` files as part of CI/CD review process

### Rollbacks

Its important understand that actions push your system towards a desired state.
Rather than supporting `undo` functionality in smash actions my feeling is it
would be preferred to create actions that achieve the opposite desired state.
You can read previous system states in the `./smash/engine/state.*` files during
planning which provides maximum flexibility.

Interesting side effects which fell out of the design was toggling.

```
$ smash.sh -s -o make_target,undo_make_target && ls ./target
==> done
version

$ smash.sh -s -o make_target,undo_make_target && ls ./target
==> done
ls: ./target: No such file or directory

$ smash.sh -s -o make_target,undo_make_target && ls ./target
==> done
version
```

# Contributions

If you want to change behavior please create a unit test in `./test.sh`.

```tap
$ ./test.sh
1..21
start with clean workspace
ok 1 with a script of <200 lines
ok 2 we start without ./target
run ./smash.sh with no args
ok 3 script exits with 0
ok 4 work was planned
ok 5 one run script planned
ok 6 one test script planned
ok 7 work was done
ok 8 smash reports completing successfully
ok 9 we log everything to the user
ok 10 we now have the artifact ./target/version
run ./smash.sh again
ok 11 script exits with 0
ok 12 no work was planned
ok 13 no work was done
clear the workspace and do a dry run
ok 14 smash did not create ./target
ok 15 we log everything to the user
ok 16 both planned steps were dry run
ok 17 smash reports completing successfully
run smash plan silently
ok 18 we have the artifact ./target/version
ok 19 nothing gets logged to the user
ok 20 except that smash was successfully completed
clean all test artifacts
ok 21 ran expected number of tests in ./test.sh
```

Otherwise I welcome changes early in the development of this project!
