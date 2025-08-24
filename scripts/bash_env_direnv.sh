# this file is meant to be set as `$BASH_ENV`, so that non-login
# non-interactive shells still load direnv/.envrc

# note: output for debugging is fine, but it will probably break stuff,
# including direnv, because we're outputting random stuff on every
# bash-invocation

# set -x
# echo FOOBAR x "$VSCODE_ESM_ENTRYPOINT" x "$DIRENV_FILE" x "$BASH_ENV_DIRENV_ENTERED" x
if [[ -n "$VSCODE_ESM_ENTRYPOINT" && -n "$DIRENV_FILE" && -z "$BASH_ENV_DIRENV_ENTERED" ]]; then
	# echo BARFOO
	export BASH_ENV_DIRENV_ENTERED="1"
	unset DIRENV_FILE

	# `direnv export bash 2>/dev/null` is necessary to remove annoying always-on output of direnv.
	# DIRENV_LOG_FORMAT="" doesn't help atm, see https://github.com/direnv/direnv/pull/1475
	eval "$(direnv export bash 2>/dev/null)"
fi
# set +x
