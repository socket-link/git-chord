# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

git-chord is a zsh plugin that provides vim-style composable git commands. Users chain single-character git operations into "chords" that execute sequentially, similar to vim keybindings.

Example: `g acp "Fix bug"` executes: git add . → git commit -m "Fix bug" → git push

## Core Architecture

### Single Entry Point (git-chord.zsh)

All functionality lives in one zsh file. The architecture consists of:

1. **Three Command Registries** (associative arrays at top of file):
   - `GIT_CHORD_CMDS`: Single-char commands (a, c, p, x, etc.)
   - `GIT_CHORD_MULTI`: Multi-char commands (pf, pu, ra, rc, etc.)
   - `GIT_CHORD_MACROS`: Macro commands that capture current branch (R, M, W)

2. **Parser Pipeline** (_git_chord_parse:94-186):
   - Parses chord string character-by-character
   - Handles three types of argument binding:
     - Inline quoted: `x"branch"` binds "branch" explicitly to x
     - Positional: `xacp branch "msg"` binds left-to-right to commands that need args
     - Defaults: Some commands have defaults (x defaults to "main")
   - Macros expand to multiple commands with {branch} substitution
   - Commands execute sequentially; failures stop the chain

3. **Executor** (_git_chord_exec:188-229):
   - Takes parsed command + argument
   - Looks up template from registry
   - Handles optional args with `::default` syntax in templates
   - Substitutes {} with argument value
   - Uses `eval` to execute the final git command

### Command Registry Format

**Single-char** (GIT_CHORD_CMDS):
```
[char]="needs_arg:template::default"
```
- `needs_arg`: 0=none, 1=required, 2=optional
- `template`: Command with {} for substitution
- `::default`: Optional default value for arg

**Multi-char** (GIT_CHORD_MULTI):
```
[chars]="full git command"
```

**Macros** (GIT_CHORD_MACROS):
```
[char]="cmd1:cmd2:cmd3 arg:cmd4 {branch}"
```
- Colon-separated command sequence
- `{branch}` gets replaced with branch at chord start

## Testing

No automated test suite exists. Manual testing workflow:

1. Source the file: `source git-chord.zsh`
2. Test in a git repo: `g <chord>`
3. Use `ghelp` to verify help output
4. Test common chords: `g acp`, `g xF`, `g R`, etc.
5. Test argument binding: both inline quoted and positional

## Making Changes

When adding/modifying commands:

1. **Add to correct registry** at top of file (lines 14-76)
2. **Follow the format exactly** - parser depends on it
3. **Test argument binding** - inline quoted vs positional
4. **Verify macro expansion** if adding macros
5. **Update ghelp()** function (lines 283-340) if adding user-facing commands
6. **Consider adding convenience alias** (lines 251-277) for muscle memory

Critical: The parser uses character indices and string slicing. Changes to parsing logic require careful testing of:
- Quote handling in _git_chord_parse:150-158
- Multi-char command detection (must check before single-char)
- Macro expansion with {branch} substitution

## Installation

Users install via:
```bash
git clone <repo> ~/.git-chord
source ~/.git-chord/git-chord.zsh  # add to .zshrc
```

The install.sh script automates this but is optional.

## Key Design Constraints

- **All functionality in one file** - users can copy/paste it anywhere
- **No external dependencies** - pure zsh, no ruby/python/node
- **Fail fast** - if any command in chain fails, stop execution
- **Branch capture** - macros capture branch at chord START, not during expansion
- **Positional args consumed left-to-right** - commands that need args grab from positional array in order
