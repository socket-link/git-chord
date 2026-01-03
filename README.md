# git-chord

Vim-style composable git commands for zsh. Chain multiple git operations in a single keystroke sequence.

```bash
g acp "Fix bug"              # add → commit → push
g x"feature"ac"WIP"p         # checkout feature → add → commit "WIP" → push  
g ac"Done"R                  # commit → sync-rebase from main (auto-returns to branch)
```

## Why?

Most git alias systems will give you shortcuts like `ga` for `git add`. 

That's fine, but you still need to type:

```bash
ga && gc "message" && gp
```

But with `git-chord`, you just type:

```bash
g acp "message"
```

The chord `acp` is parsed character-by-character: **a**dd, **c**ommit, **p**ush. 

Arguments are bound automatically to the commands that need them.

### Features

- **Single-char commands** compose into chords
- **Inline quoted args** for explicit binding: `g x"main"ac"msg"p`
- **Positional args** consumed left-to-right: `g xacp main "msg"`
- **Macros** that capture your current branch and return to it
- **Sensible defaults** (`x` → `x main`, `r` → `r main`)

## Install

```bash
# Clone
git clone https://github.com/socket-link/git-chord.git ~/.git-chord

# Add to ~/.zshrc
echo 'source ~/.git-chord/git-chord.zsh' >> ~/.zshrc
source ~/.zshrc
```

Or just copy `git-chord.zsh` anywhere and source it.

## Quick Reference

| Key | Command | Key | Command |
|-----|---------|-----|---------|
| `a` | `git add .` | `s` | `git status` |
| `c` | `git commit -m "<msg>"` | `p` | `git push` |
| `P` | `git push --force` | `f` | `git fetch` |
| `F` | `git pull` | `l` | `git log --oneline` |
| `u` | `git reset HEAD^ --soft` | `L` | `git log` |
| `x` | `git checkout [main]` | `n` | `git checkout -b <branch>` |
| `d` | `git branch -D <branch>` | `b` | `git branch` |
| `m` | `git merge <branch>` | `r` | `git rebase [main]` |
| `e` | `git commit --amend` | `E` | `git commit --amend --no-edit` |
| `h` | `git stash` | `H` | `git stash pop` |
| `S` | `git diff --staged` | | |

### Multi-char Commands

| Chord | Command |
|-------|---------|
| `pf` | `git push --force` |
| `pu` | `git push -u origin HEAD` |
| `ra` | `git rebase --abort` |
| `rc` | `git rebase --continue` |
| `rs` | `git rebase --skip` |
| `ha` | `git stash apply` |
| `hl` | `git stash list` |
| `hp` | `git stash pop` |
| `hd` | `git stash drop` |

### Macros

Macros capture your current branch at chord start and can return to it.

| Macro | Expands To | Use Case |
|-------|------------|----------|
| `R` | `x` → `F` → `x {branch}` → `r` | Sync-rebase from main |
| `M` | `x` → `F` → `x {branch}` → `m main` | Sync-merge from main |
| `W` | `p` → `x` | Push & return to main |

**Example:** On branch `feature-123`:
```bash
g ac"WIP"R
```
Expands to:
```
→ git add .
→ git commit -m "WIP"
⚡ Macro R → expanding for branch 'feature-123'
→ git checkout main
→ git pull
→ git checkout feature-123
→ git rebase main
```

## Argument Binding

Commands that need arguments get them in two ways:

### Positional (left-to-right)

```bash
g xacp feature "Add feature"
#      │  │
#      │  └─ "Add feature" → c (commit)
#      └──── "feature" → x (checkout)
```

### Inline Quoted

```bash
g x"feature"ac"Add feature"p
```

Quoted args bind explicitly, which is useful when the argument order would otherwise be ambiguous.

## Workflows

```bash
# Morning sync
g xF                             # checkout main, pull

# Quick commit
g acp "Fix typo"                 # add, commit, push

# Start feature
g n"feature-123"                 # new branch
g acp "Implement feature"        # work...
g R                              # sync-rebase from main
g P                              # force push (after rebase)

# Stash & switch
g h                              # stash
g xF                             # main, pull
g x"feature"H                    # back, unstash

# Oops, bad commit
g u                              # uncommit
g ac "Better message"            # recommit

# Squash into previous
g aE                             # add + amend no-edit

# Done with branch
g W                              # push, back to main
```

## Mnemonics

| Key | Mnemonic                     |
|-----|------------------------------|
| `x` | "check" (as in checkout)     |
| `n` | "new" branch                 |
| `u` | "uncommit"                   |
| `h` | "hold" (stash)               |
| `H` | "unHold" (pop)               |
| `e` | "edit" commit                |
| `E` | "Edit silently"              |
| `S` | "power Status" (staged diff) |
| `R` | "sync Rebase"                |
| `M` | "sync Merge"                 |
| `W` | "Wrap up"                    |

## Convenience Mappings

For improved muscle-memory, aliases for common commands are included at the bottom.

These alias allow you to omit space after typing `g`, speeding up the chord typing (`ga`, `gc`, `gx`, etc.).

## Extending

Edit the associative arrays in `git-chord.zsh`:

```zsh
# Add a single-char command
GIT_CHORD_CMDS[w]="1:git worktree add {}"

# Add a multi-char command
GIT_CHORD_MULTI[df]="git diff --name-only"

# Add a macro
GIT_CHORD_MACROS[Q]="h:x:F:x {branch}:H"  # stash, sync, unstash
```

## Help

```bash
ghelp
```

## License

```
Copyright 2026 Miley Chandonnet, Stedfast Softworks LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
