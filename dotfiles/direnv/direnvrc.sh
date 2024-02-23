layout_poetry() {
	# adapted from https://github.com/direnv/direnv/issues/592#issuecomment-1849743637

	if [[ ! -f pyproject.toml ]]; then
		log_error 'poetry: No pyproject.toml found. Use `poetry new` or `poetry init` to create one first.'
		exit 2
	fi

	LOCK="$PWD/poetry.lock"
	watch_file "$LOCK"

	local VENV=$(poetry env info --path)
	if [[ -z $VENV || ! -d $VENV/bin ]]; then
		log_status 'poetry: No poetry virtual environment found. Running `poetry install` to create one.'
		poetry install
		VENV=$(poetry env info --path)
	fi

	if [[ poetry.lock -nt "$(direnv_layout_dir)/_poetry.lock" ]]; then
		log_status 'poetry: Environment is out of date. Running `poetry install --sync`.'
		poetry install --sync
		cp poetry.lock "$(direnv_layout_dir)/_poetry.lock"
	fi

	export VIRTUAL_ENV=$VENV
	export POETRY_ACTIVE=1
	PATH_add "$VENV/bin"

	log_status 'poetry: Entered project virtualenv'
}
