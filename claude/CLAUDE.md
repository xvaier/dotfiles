## Voice
Be direct. Have opinions. Use specific examples and names, not vague claims. State your point first, then support it. Trust the reader to recognise what matters without labelling it as "significant" or "important."

# Banned
- Don't use weird metaphors or cliché phrase structures.
- Do not commit, push or otherwise persist changes unless you have explicit approval.

## Structure
- Vary paragraph and sentence length. Don't write uniform blocks.
- Never use the "Bold term: explanation sentence" list format. It's the single most recognisable AI pattern.
- Don't signpost ("Let's explore," "Now let's turn to"). Just make your point.
- Don't open with a sweeping contextual statement. Don't close with a summary or inspirational wrap-up. Start and end on substance.
- Don't restate the question back before answering it.

# Coding Preferences
- Simple, clean code. Prefer clarity over cleverness.
- Comments only when the code isn't self-explanatory.
- Concise but readable—don't sacrifice understanding for brevity.
- Avoid tight coupling, but don't over-abstract. The right abstraction is worth waiting for.

## Testing
- Depend on the CI to run the full test suite, run only targeted tests based on changes locally
- Test behavior, not implementation. Lock in what the code does, not how.
- Avoid mocks unless there's no practical alternative (network, filesystem, etc.)—prefer real objects so tests break when code drifts.
- Enough tests to catch regressions, not every permutation.

# Shell
My shell is zsh with zim's `environment` module, so `NO_CLOBBER`, `EXTENDED_GLOB` and zsh's default `NOMATCH` are all on. Bash habits break in a few predictable ways:
- `>` fails with "file exists" on an existing file. Use `>|` to overwrite deliberately. `>>` also fails on a missing file, so use `>>|` or create the file first. For anything non-trivial, use the Write tool instead of redirecting.
- Unmatched globs are errors, not literals. Quote anything with `?`, `*`, `[`, `^`, `~` or `#` in it: URLs with query strings, `find -name '*.ts'`, `git reset 'HEAD^'` (or use `HEAD~1`).
- Unquoted `$var` is not word-split. Use an array (`files=(a b); cmd $files`) or `${=var}` if splitting is the goal.
- Tools are macOS/BSD, not GNU: `sed -i ''`, no `grep -P`, `date` and `stat` flags differ.
- If a script needs bash semantics, write it with a `#!/usr/bin/env bash` shebang or run it with `bash -c`, rather than fighting zsh.

# Merging/Worktrees
- I prefer working in a single branch with stacked commits, then opening a stack of merge/pull requests from the commits.
- If signing commits times out during long running sessions, you can temporarily commit without signing, as long as the commits are rebased with a signature before pushing.
- Manage worktrees with my `wt` command, not raw `git worktree` or the EnterWorktree tool: `wt new <name>` creates a branch and worktree off the default branch, `wt new --existing <name>` checks out an existing branch, `wt <name>` switches, `wt rm <name>` removes. Always pass a name, because without one it opens a picker.
- Split a worktree's commits into stacked CRs with `wt stack plan` / `wt stack apply -` (the plan's header comments explain the format)

# Planning
- Plans should be concise and human readable, while still covering the whole plan and conveying intent.
