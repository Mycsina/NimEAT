# Nim & Jujutsu (jj) Development Cheat Sheet

## Nim Tooling
Action	Command	Note
Test All	nimble test	Runs unit + integration tests
Test Fast	nimble testFast	Unit tests only (for rapid loops)
Benchmark	nimble bench	Performance checks
Build/Run	nimble runxor	Runs main binary/example
Clean	nimble clear	Removes build artifacts
💎 Jujutsu (jj) Protocol

Core Concept: jj has no staging index. The working copy is always the commit @.
1. Safety & Status (Do this first)

    Check State: jj status

        Always run this before modifying files to see parent commit and conflict state.

    Visualize Graph: jj log

        View the hierarchy of commits.

    Undo Mistake: jj undo

        Reverts the immediate last repo operation (reflog equivalent).

2. Standard Dev Loop

    Start New Feature:
    Bash

jj new main
# Creates a new anonymous working copy off 'main'

Edit Files: (Make changes in file system)

Check Diff:
Bash

jj diff

Commit/Describe:
Bash

    jj describe -m "feat: description of changes"

3. Modifying History (Refactoring)

    Amend Parent (Squash):
    Bash

jj squash
# Moves ALL changes from working copy into the parent revision

Partial Amend:
Bash

jj squash --path src/main.nim
# Moves ONLY specific file changes into parent

Delete/Drop Revision:
Bash

    jj abandon <revision_id>
    # If empty, just use 'jj abandon'

4. Git Syncing (Push/Pull)

    Update Remote:
    Bash

jj git fetch

Rebase WIP on new Main:
Bash

jj rebase -s <your_change_id> -d main
# Moves your change stack onto the updated main

Prepare to Push (Bookmarks):
Bash

jj bookmark set <branch_name> -r @
# Assigns a git-compatible branch name to the current revision

Push:
Bash

    jj git push

5. Conflict Resolution

If jj status shows "Conflicted":

    View Conflicts: jj resolve --list

    Fix: Edit files manually (look for <<<< markers).

    Verify: Run jj status (Conflicts resolve automatically when markers are removed).

    No git add needed.