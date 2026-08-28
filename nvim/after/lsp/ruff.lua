return {
  -- explicit path: the pyenv shim shadows brew's ruff and errors when the
  -- active python version doesn't have ruff installed
  cmd = { "/opt/homebrew/bin/ruff", "server" },
}
