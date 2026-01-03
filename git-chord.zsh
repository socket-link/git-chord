#!/usr/bin/env zsh
# git-chord - Vim-style composable git commands
# https://github.com/socket-link/git-chord
#
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# Command Registry
# =============================================================================
# Format: CMD_CHAR -> "needs_arg:command_template"
# needs_arg: 0 = no arg, 1 = required arg, 2 = optional arg (has default)
# command_template: use {} for arg substitution

typeset -A GIT_CHORD_CMDS
GIT_CHORD_CMDS=(
  # Basic operations
  [a]="0:git add ."
  [s]="0:git status"
  [f]="0:git fetch"
  [F]="0:git pull"
  [l]="0:git log --oneline -20"
  [L]="0:git log"
  [u]="0:git reset HEAD^ --soft"
  [p]="0:git push"
  [P]="0:git push --force"
  
  # Branch operations
  [x]="2:git checkout {}::main"        # x = "check" (default: main)
  [n]="1:git checkout -b {}"           # n = "new branch"
  [d]="1:git branch -D {}"             # d = "delete branch"
  [b]="2:git branch {}::"              # b = "branch" (default: list)
  [m]="1:git merge {}"                 # m = "merge"
  
  # Commit operations
  [c]="1:git commit -m \"{}\""         # c = "commit"
  [e]="0:git commit --amend"           # e = "edit last commit"
  [E]="0:git commit --amend --no-edit" # E = "amend without edit"
  
  # Rebase operations
  [r]="2:git rebase {}::main"          # r = "rebase" (default: main)
  
  # Stash operations (h = "hold")
  [h]="0:git stash"
  [H]="0:git stash pop"                # H = "unhold" (uppercase)
  
  # Diff
  [S]="0:git diff --staged"            # S = "power Show" (staged diff)
)

# Multi-character commands (parsed before single-char)
typeset -A GIT_CHORD_MULTI
GIT_CHORD_MULTI=(
  [pf]="git push --force"
  [pu]="git push -u origin HEAD"
  [ra]="git rebase --abort"
  [rc]="git rebase --continue"
  [rs]="git rebase --skip"
  [ha]="git stash apply"
  [hl]="git stash list"
  [hp]="git stash pop"
  [hd]="git stash drop"
)

# Macro commands - use {branch} for the branch captured at chord start
# Format: "commands to run" where {branch} gets substituted
typeset -A GIT_CHORD_MACROS
GIT_CHORD_MACROS=(
  # R = "sync Rebase" - go to main, pull, come back, rebase
  [R]="x:F:x {branch}:r"
  
  # M = "sync Merge" - go to main, pull, come back, merge main
  [M]="x:F:x {branch}:m main"
  
  # W = "Wrap up" - push and come back to main
  [W]="p:x"
)

# =============================================================================
# Branch Utilities  
# =============================================================================

_git_current_branch() {
  git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
}

_git_default_branch() {
  git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
}

# =============================================================================
# Chord Parser
# =============================================================================

_git_chord_parse() {
  local chord="$1"
  shift
  local -a positional_args=("$@")
  local -a commands=()
  local -a args=()
  local i=0
  local len=${#chord}
  local pos_idx=0
  
  # Capture current branch at start for macro commands
  local start_branch="$(_git_current_branch)"
  
  while (( i < len )); do
    local char="${chord:$i:1}"
    local next_char="${chord:$((i+1)):1}"
    local two_char="${char}${next_char}"
    
    # Check for macro commands first
    if [[ -n "${GIT_CHORD_MACROS[$char]}" ]]; then
      local macro="${GIT_CHORD_MACROS[$char]}"
      macro="${macro//\{branch\}/$start_branch}"
      
      echo "⚡ Macro $char → expanding for branch '$start_branch'" >&2
      
      local IFS=':'
      local -a macro_parts=($macro)
      unset IFS
      
      for part in "${macro_parts[@]}"; do
        local macro_cmd="${part%% *}"
        local macro_arg="${part#* }"
        [[ "$macro_cmd" == "$macro_arg" ]] && macro_arg=""
        
        commands+=("$macro_cmd")
        args+=("$macro_arg")
      done
      
      (( i++ ))
      continue
    fi
    
    # Check for multi-character commands
    if [[ -n "${GIT_CHORD_MULTI[$two_char]}" ]]; then
      commands+=("$two_char")
      args+=("")
      (( i += 2 ))
      continue
    fi
    
    # Check for single-character command
    if [[ -n "${GIT_CHORD_CMDS[$char]}" ]]; then
      commands+=("$char")
      (( i++ ))
      
      # Check for quoted argument
      if [[ "${chord:$i:1}" == '"' ]]; then
        (( i++ ))
        local arg=""
        while (( i < len )) && [[ "${chord:$i:1}" != '"' ]]; do
          arg+="${chord:$i:1}"
          (( i++ ))
        done
        (( i++ ))
        args+=("$arg")
      else
        local spec="${GIT_CHORD_CMDS[$char]}"
        local needs_arg="${spec%%:*}"
        if (( needs_arg > 0 )) && (( pos_idx < ${#positional_args[@]} )); then
          args+=("${positional_args[$((pos_idx+1))]}")
          (( pos_idx++ ))
        else
          args+=("")
        fi
      fi
    else
      echo "✗ Unknown command: $char" >&2
      return 1
    fi
  done
  
  # Execute commands in sequence
  local idx=1
  for cmd in "${commands[@]}"; do
    local arg="${args[$idx]}"
    
    if ! _git_chord_exec "$cmd" "$arg"; then
      echo "✗ Command failed: $cmd" >&2
      return 1
    fi
    (( idx++ ))
  done
}

_git_chord_exec() {
  local cmd="$1"
  local arg="$2"
  local template=""
  
  # Check multi-char commands first
  if [[ -n "${GIT_CHORD_MULTI[$cmd]}" ]]; then
    template="${GIT_CHORD_MULTI[$cmd]}"
    echo "→ $template" >&2
    eval "$template"
    return $?
  fi
  
  # Single-char command
  local spec="${GIT_CHORD_CMDS[$cmd]}"
  local needs_arg="${spec%%:*}"
  template="${spec#*:}"
  
  # Handle optional args with defaults (format: "template::default")
  local default=""
  if [[ "$template" == *"::"* ]]; then
    default="${template##*::}"
    template="${template%%::*}"
  fi
  
  # Apply argument or default
  if [[ -n "$arg" ]]; then
    template="${template//\{\}/$arg}"
  elif [[ -n "$default" ]]; then
    template="${template//\{\}/$default}"
  elif (( needs_arg == 1 )); then
    echo "✗ Command '$cmd' requires an argument" >&2
    return 1
  else
    template="${template//\{\}/}"
  fi
  
  template="${template%% }"
  
  echo "→ $template" >&2
  eval "$template"
}

# =============================================================================
# Main Entry Point
# =============================================================================

g() {
  if [[ $# -eq 0 ]]; then
    git status
    return
  fi
  
  local chord="$1"
  shift
  
  _git_chord_parse "$chord" "$@"
}

# =============================================================================
# Convenience Aliases (backward compatibility)
# =============================================================================

alias ga='g a'
alias gc='g c'
alias gx='g x'
alias gn='g n'
alias gu='g u'
alias gf='g f'
alias gF='g F'
alias gl='g l'
alias gs='g s'
alias gS='g S'
alias gr='g r'
alias gra='g ra'
alias grc='g rc'
alias grs='g rs'
alias gp='g p'
alias gpf='g pf'
alias gpu='g pu'
alias gd='g d'
alias gb='g b'
alias gh='g h'
alias gha='g ha'
alias ghl='g hl'
alias ghp='g hp'
alias ghd='g hd'
alias gm='g m'
alias ge='g e'
alias gE='g E'

# =============================================================================
# Help
# =============================================================================

ghelp() {
  cat << 'EOF'
git-chord - Vim-style composable git commands

USAGE
  g <chord> [args...]

SYNTAX
  g acp "Fix bug"              Positional args (no spaces in chord)
  g x"branch"ac"message"p      Inline quoted args

COMMANDS
  a   add .                    s   status
  c   commit -m "<msg>"        p   push
  P   push --force             f   fetch
  F   pull                     l   log --oneline
  L   log (full)               u   uncommit (reset --soft)
  
  x   checkout [branch]        (default: main)
  n   checkout -b <branch>     (new)
  d   branch -D <branch>       (delete)
  b   branch [arg]             (no arg = list)
  m   merge <branch>
  
  e   commit --amend           (edit)
  E   commit --amend --no-edit
  
  r   rebase [branch]          (default: main)
  
  h   stash                    (hold)
  H   stash pop                (unHold)
  
  S   diff --staged            (power Show)

MULTI-CHAR
  pf  push --force             pu  push -u origin HEAD
  ra  rebase --abort           rc  rebase --continue
  rs  rebase --skip
  ha  stash apply              hl  stash list
  hp  stash pop                hd  stash drop

MACROS (capture current branch)
  R   Sync-Rebase: x → F → x {branch} → r
  M   Sync-Merge:  x → F → x {branch} → m main
  W   Wrap-up:     p → x

EXAMPLES
  g                            git status
  g acp "Fix bug"              add, commit, push
  g x                          checkout main
  g xF                         checkout main, pull
  g n"feature"ac"WIP"          new branch, add, commit
  g hxFH                       stash, checkout main, pull, pop
  g ac"Done"R                  commit, sync-rebase from main
  g aE                         add, amend (no edit)

EOF
}
