# Smash

>  Change the state of the universe, from &lt;200 lines of bash!

<img title="" src="docs/lemme-smash.gif" alt="lemme-smash" data-align="left">

## Introduction

I liked `terraform`, but I wanted to be evil and use the full power of bash. 👺

Using simple scripts, determine system state and create plans to change it.

```
usage: smash [-anpst] [-o action,..]
  -o Only run comma seperated list of actions.
  -p Plan only; generate an execution plan. Can be approved in PR.
  -a Apply only; ensure state has not changed, and execute plan.
  -n Dry run; print the commands that would be executed, but do not execute them.
  -s Silent operation; do not print to stdout as they are executed.
  -t Output planned tests in tap format.
```

Lets create a simple smash action to install your dotfiles!

```sh
# Create action directory
mkdir -p smash/install_mac

# We are going to need a script to install your dotfiles
echo 'git clone https://github.com/username/dotfiles.git ~/.dotfiles' > install.sh

# Another to determine if dotfiles are installed
echo '
#!/bin/bash
echo "DOTFILES_INSTALLED=$(test -d ~/.dotfiles && echo true)"
' > smash/install_mac/state

# Use that context to plan what must be done to install your dotfiles
echo '
#!/bin/bash

if [[ "$DOTFILES_INSTALLED" != "true" ]]; then
  echo "run bash ./install.sh"
fi

# You could optionally add unit tests
echo "test [[ -d ~/.dotfiles ]] || exit 1"
' > smash/install_mac/state

# Make them all executablable
chmod +x ./smash/install_mac/* ./install.sh

# Test your action with a dry run first.
smash -n
# Create a plan
smash -p
# Review plan
cat ./smash/engine/plan
# Apply plan
smash -a

# Or dont be a Becky...
smash
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

## Installation methods

**source**

```
sudo curl -L --fail \
  https://raw.githubusercontent.com/expelledboy/smash/master/smash.sh \
  -o /usr/local/bin/smash
sudo chmod +x /usr/local/bin/smash
```

**docker**

```
docker run --rm -it -v "${PWD}:/code" expelledboy/smash:latest -o make_target
```

## Guide

- Your actions must be directories installed in `./smash/<action>`
  - A smash action needs only one file `./smash/<action>/plan`
  - Actions can contribute to state in `./smash/<action>/state`
  - By default all actions in `./smash/*` are run unless you use the `-o` option
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
  - There are also pre and post hooks eg. `pre-plan` `plan` `post-plan`
  - Create a hook by printing to stdout in the plan script `<hook> cmd args`
- You can create global util scripts in `./smash/scripts/*`
  - These will be available in all phases
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

Otherwise I welcome changes early in the development of this project!
