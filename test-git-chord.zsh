#!/usr/bin/env zsh
# test-git-chord.zsh - Unit tests for git-chord
#
# Run with: zsh test-git-chord.zsh
#
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# Test Framework
# =============================================================================

typeset -g TEST_PASSED=0
typeset -g TEST_FAILED=0
typeset -g CAPTURED_COMMANDS=()
typeset -g MOCK_BRANCH="feature-branch"
typeset -g MOCK_GIT_FAIL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-Values should be equal}"

  if [[ "$expected" == "$actual" ]]; then
    return 0
  else
    echo "${RED}FAIL${NC}: $msg"
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-Should contain substring}"

  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  else
    echo "${RED}FAIL${NC}: $msg"
    echo "  String: '$haystack'"
    echo "  Should contain: '$needle'"
    return 1
  fi
}

assert_array_eq() {
  local -a expected=("${(P@)1}")
  local -a actual=("${(P@)2}")
  local msg="${3:-Arrays should be equal}"

  if [[ ${#expected[@]} -ne ${#actual[@]} ]]; then
    echo "${RED}FAIL${NC}: $msg (length mismatch)"
    echo "  Expected length: ${#expected[@]}"
    echo "  Actual length:   ${#actual[@]}"
    return 1
  fi

  for i in {1..${#expected[@]}}; do
    if [[ "${expected[$i]}" != "${actual[$i]}" ]]; then
      echo "${RED}FAIL${NC}: $msg (element $i differs)"
      echo "  Expected[$i]: '${expected[$i]}'"
      echo "  Actual[$i]:   '${actual[$i]}'"
      return 1
    fi
  done
  return 0
}

run_test() {
  local name="$1"
  local func="$2"

  # Reset captured commands before each test
  CAPTURED_COMMANDS=()
  MOCK_GIT_FAIL=0

  echo -n "  $name... "

  if $func 2>/dev/null; then
    echo "${GREEN}PASS${NC}"
    (( TEST_PASSED++ ))
  else
    (( TEST_FAILED++ ))
  fi
}

# =============================================================================
# Git Mock
# =============================================================================

# Replace eval to capture commands instead of executing them
_original_eval() {
  builtin eval "$@"
}

# Mock git to capture commands
mock_git() {
  CAPTURED_COMMANDS+=("$*")
  if (( MOCK_GIT_FAIL )); then
    return 1
  fi
  return 0
}

# Override _git_chord_exec to capture instead of eval
_git_chord_exec_mock() {
  local cmd="$1"
  local arg="$2"
  local template=""

  # Check multi-char commands first
  if [[ -n "${GIT_CHORD_MULTI[$cmd]}" ]]; then
    template="${GIT_CHORD_MULTI[$cmd]}"
    CAPTURED_COMMANDS+=("$template")
    return $MOCK_GIT_FAIL
  fi

  # Single-char command
  local spec="${GIT_CHORD_CMDS[$cmd]}"
  local needs_arg="${spec%%:*}"
  template="${spec#*:}"

  # Handle optional args with defaults
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
    return 1
  else
    template="${template//\{\}/}"
  fi

  template="${template%% }"
  CAPTURED_COMMANDS+=("$template")
  return $MOCK_GIT_FAIL
}

# Mock version of _git_current_branch
_git_current_branch_mock() {
  echo "$MOCK_BRANCH"
}

# =============================================================================
# Load git-chord and set up mocks
# =============================================================================

SCRIPT_DIR="${0:a:h}"
source "$SCRIPT_DIR/git-chord.zsh"

# Save original functions
functions[_git_chord_exec_original]=$functions[_git_chord_exec]
functions[_git_current_branch_original]=$functions[_git_current_branch]

# Override with mocks for testing
_git_chord_exec() { _git_chord_exec_mock "$@" }
_git_current_branch() { _git_current_branch_mock }

# Override git command itself for any direct calls
git() {
  CAPTURED_COMMANDS+=("git $*")
  return $MOCK_GIT_FAIL
}

# =============================================================================
# Test Cases: Basic Commands
# =============================================================================

test_empty_chord_runs_status() {
  CAPTURED_COMMANDS=()
  g
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git status" "${CAPTURED_COMMANDS[1]}" "Should run git status"
}

test_single_char_add() {
  CAPTURED_COMMANDS=()
  g a
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git add ." "${CAPTURED_COMMANDS[1]}" "Should run git add ."
}

test_single_char_status() {
  CAPTURED_COMMANDS=()
  g s
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git status" "${CAPTURED_COMMANDS[1]}" "Should run git status"
}

test_single_char_fetch() {
  CAPTURED_COMMANDS=()
  g f
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git fetch" "${CAPTURED_COMMANDS[1]}" "Should run git fetch"
}

test_single_char_pull() {
  CAPTURED_COMMANDS=()
  g F
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git pull" "${CAPTURED_COMMANDS[1]}" "Should run git pull"
}

test_single_char_push() {
  CAPTURED_COMMANDS=()
  g p
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git push" "${CAPTURED_COMMANDS[1]}" "Should run git push"
}

test_single_char_force_push() {
  CAPTURED_COMMANDS=()
  g P
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git push --force" "${CAPTURED_COMMANDS[1]}" "Should run git push --force"
}

test_single_char_log() {
  CAPTURED_COMMANDS=()
  g l
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git log --oneline -20" "${CAPTURED_COMMANDS[1]}" "Should run git log"
}

test_single_char_stash() {
  CAPTURED_COMMANDS=()
  g h
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git stash" "${CAPTURED_COMMANDS[1]}" "Should run git stash"
}

test_single_char_stash_pop() {
  CAPTURED_COMMANDS=()
  g H
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git stash pop" "${CAPTURED_COMMANDS[1]}" "Should run git stash pop"
}

# =============================================================================
# Test Cases: Commands with Arguments
# =============================================================================

test_commit_with_positional_arg() {
  CAPTURED_COMMANDS=()
  g c "My commit message"
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq 'git commit -m "My commit message"' "${CAPTURED_COMMANDS[1]}" "Should run git commit with message"
}

test_checkout_default_to_main() {
  CAPTURED_COMMANDS=()
  g x
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git checkout main" "${CAPTURED_COMMANDS[1]}" "Should checkout main by default"
}

test_checkout_with_branch_arg() {
  CAPTURED_COMMANDS=()
  g x develop
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git checkout develop" "${CAPTURED_COMMANDS[1]}" "Should checkout specified branch"
}

test_new_branch() {
  CAPTURED_COMMANDS=()
  g n feature-x
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git checkout -b feature-x" "${CAPTURED_COMMANDS[1]}" "Should create new branch"
}

test_delete_branch() {
  CAPTURED_COMMANDS=()
  g d old-branch
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git branch -D old-branch" "${CAPTURED_COMMANDS[1]}" "Should delete branch"
}

test_rebase_default_to_main() {
  CAPTURED_COMMANDS=()
  g r
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git rebase main" "${CAPTURED_COMMANDS[1]}" "Should rebase on main by default"
}

test_rebase_with_branch() {
  CAPTURED_COMMANDS=()
  g r develop
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git rebase develop" "${CAPTURED_COMMANDS[1]}" "Should rebase on specified branch"
}

test_merge_branch() {
  CAPTURED_COMMANDS=()
  g m feature-x
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git merge feature-x" "${CAPTURED_COMMANDS[1]}" "Should merge branch"
}

# =============================================================================
# Test Cases: Inline Quoted Arguments
# =============================================================================

test_inline_quoted_commit() {
  CAPTURED_COMMANDS=()
  g 'c"Inline message"'
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq 'git commit -m "Inline message"' "${CAPTURED_COMMANDS[1]}" "Should use inline quoted message"
}

test_inline_quoted_checkout() {
  CAPTURED_COMMANDS=()
  g 'x"my-branch"'
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git checkout my-branch" "${CAPTURED_COMMANDS[1]}" "Should checkout inline quoted branch"
}

test_inline_quoted_new_branch() {
  CAPTURED_COMMANDS=()
  g 'n"new-feature"'
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git checkout -b new-feature" "${CAPTURED_COMMANDS[1]}" "Should create inline quoted branch"
}

# =============================================================================
# Test Cases: Command Chaining
# =============================================================================

test_add_commit_chain() {
  CAPTURED_COMMANDS=()
  g ac "Fix bug"
  assert_eq 2 ${#CAPTURED_COMMANDS[@]} "Should capture two commands" && \
  assert_eq "git add ." "${CAPTURED_COMMANDS[1]}" "First should be add" && \
  assert_eq 'git commit -m "Fix bug"' "${CAPTURED_COMMANDS[2]}" "Second should be commit"
}

test_add_commit_push_chain() {
  CAPTURED_COMMANDS=()
  g acp "Feature complete"
  assert_eq 3 ${#CAPTURED_COMMANDS[@]} "Should capture three commands" && \
  assert_eq "git add ." "${CAPTURED_COMMANDS[1]}" "First should be add" && \
  assert_eq 'git commit -m "Feature complete"' "${CAPTURED_COMMANDS[2]}" "Second should be commit" && \
  assert_eq "git push" "${CAPTURED_COMMANDS[3]}" "Third should be push"
}

test_checkout_pull_chain() {
  CAPTURED_COMMANDS=()
  g xF
  assert_eq 2 ${#CAPTURED_COMMANDS[@]} "Should capture two commands" && \
  assert_eq "git checkout main" "${CAPTURED_COMMANDS[1]}" "First should be checkout main" && \
  assert_eq "git pull" "${CAPTURED_COMMANDS[2]}" "Second should be pull"
}

test_stash_checkout_pull_pop_chain() {
  CAPTURED_COMMANDS=()
  g hxFH
  assert_eq 4 ${#CAPTURED_COMMANDS[@]} "Should capture four commands" && \
  assert_eq "git stash" "${CAPTURED_COMMANDS[1]}" "First should be stash" && \
  assert_eq "git checkout main" "${CAPTURED_COMMANDS[2]}" "Second should be checkout" && \
  assert_eq "git pull" "${CAPTURED_COMMANDS[3]}" "Third should be pull" && \
  assert_eq "git stash pop" "${CAPTURED_COMMANDS[4]}" "Fourth should be pop"
}

test_mixed_inline_and_positional() {
  CAPTURED_COMMANDS=()
  g 'x"develop"ac"message"p'
  assert_eq 4 ${#CAPTURED_COMMANDS[@]} "Should capture four commands" && \
  assert_eq "git checkout develop" "${CAPTURED_COMMANDS[1]}" "First should checkout develop" && \
  assert_eq "git add ." "${CAPTURED_COMMANDS[2]}" "Second should be add" && \
  assert_eq 'git commit -m "message"' "${CAPTURED_COMMANDS[3]}" "Third should be commit" && \
  assert_eq "git push" "${CAPTURED_COMMANDS[4]}" "Fourth should be push"
}

# =============================================================================
# Test Cases: Multi-char Commands
# =============================================================================

test_multi_char_push_force() {
  CAPTURED_COMMANDS=()
  g pf
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git push --force" "${CAPTURED_COMMANDS[1]}" "Should run push --force"
}

test_multi_char_push_upstream() {
  CAPTURED_COMMANDS=()
  g pu
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git push -u origin HEAD" "${CAPTURED_COMMANDS[1]}" "Should run push with upstream"
}

test_multi_char_rebase_abort() {
  CAPTURED_COMMANDS=()
  g ra
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git rebase --abort" "${CAPTURED_COMMANDS[1]}" "Should run rebase --abort"
}

test_multi_char_rebase_continue() {
  CAPTURED_COMMANDS=()
  g rc
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git rebase --continue" "${CAPTURED_COMMANDS[1]}" "Should run rebase --continue"
}

test_multi_char_stash_apply() {
  CAPTURED_COMMANDS=()
  g ha
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git stash apply" "${CAPTURED_COMMANDS[1]}" "Should run stash apply"
}

test_multi_char_stash_list() {
  CAPTURED_COMMANDS=()
  g hl
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git stash list" "${CAPTURED_COMMANDS[1]}" "Should run stash list"
}

# =============================================================================
# Test Cases: Macros
# =============================================================================

test_macro_R_sync_rebase() {
  CAPTURED_COMMANDS=()
  MOCK_BRANCH="my-feature"
  g R
  assert_eq 4 ${#CAPTURED_COMMANDS[@]} "Should capture four commands" && \
  assert_eq "git checkout main" "${CAPTURED_COMMANDS[1]}" "First: checkout main" && \
  assert_eq "git pull" "${CAPTURED_COMMANDS[2]}" "Second: pull" && \
  assert_eq "git checkout my-feature" "${CAPTURED_COMMANDS[3]}" "Third: checkout back" && \
  assert_eq "git rebase main" "${CAPTURED_COMMANDS[4]}" "Fourth: rebase"
}

test_macro_M_sync_merge() {
  CAPTURED_COMMANDS=()
  MOCK_BRANCH="develop"
  g M
  assert_eq 4 ${#CAPTURED_COMMANDS[@]} "Should capture four commands" && \
  assert_eq "git checkout main" "${CAPTURED_COMMANDS[1]}" "First: checkout main" && \
  assert_eq "git pull" "${CAPTURED_COMMANDS[2]}" "Second: pull" && \
  assert_eq "git checkout develop" "${CAPTURED_COMMANDS[3]}" "Third: checkout back" && \
  assert_eq "git merge main" "${CAPTURED_COMMANDS[4]}" "Fourth: merge"
}

test_macro_W_wrap_up() {
  CAPTURED_COMMANDS=()
  MOCK_BRANCH="feature"
  g W
  assert_eq 2 ${#CAPTURED_COMMANDS[@]} "Should capture two commands" && \
  assert_eq "git push" "${CAPTURED_COMMANDS[1]}" "First: push" && \
  assert_eq "git checkout main" "${CAPTURED_COMMANDS[2]}" "Second: checkout main"
}

test_macro_branch_capture() {
  # Verify that branch is captured at start, not during expansion
  CAPTURED_COMMANDS=()
  MOCK_BRANCH="original-branch"
  g R
  assert_contains "${CAPTURED_COMMANDS[3]}" "original-branch" "Should use branch captured at start"
}

test_macro_space_arg_preserved() {
  # Ensure macro parts keep spaces in args when split on ":"
  CAPTURED_COMMANDS=()
  local old_macro="${GIT_CHORD_MACROS[X]}"
  GIT_CHORD_MACROS[X]="x {branch}:m topic branch"
  MOCK_BRANCH="space-branch"
  g X
  GIT_CHORD_MACROS[X]="$old_macro"

  assert_eq 2 ${#CAPTURED_COMMANDS[@]} "Should capture two commands" && \
  assert_eq "git checkout space-branch" "${CAPTURED_COMMANDS[1]}" "First: checkout branch" && \
  assert_eq "git merge topic branch" "${CAPTURED_COMMANDS[2]}" "Second: merge with space arg"
}

# =============================================================================
# Test Cases: Error Handling
# =============================================================================

test_unknown_command_fails() {
  local output
  output=$(g z 2>&1)
  local exit_code=$?
  [[ $exit_code -ne 0 ]] && assert_contains "$output" "Unknown command: z"
}

test_missing_required_arg_fails() {
  # 'c' requires an argument
  CAPTURED_COMMANDS=()
  local output
  output=$(g c 2>&1)
  local exit_code=$?
  # Should fail because no message provided
  [[ $exit_code -ne 0 ]] || [[ ${#CAPTURED_COMMANDS[@]} -eq 0 ]]
}

test_command_failure_stops_chain() {
  CAPTURED_COMMANDS=()
  MOCK_GIT_FAIL=1
  g acp "test" 2>/dev/null || true
  # Should stop after first failure
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should stop after first command fails"
}

# =============================================================================
# Test Cases: Edge Cases
# =============================================================================

test_branch_list_no_arg() {
  CAPTURED_COMMANDS=()
  g b
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git branch" "${CAPTURED_COMMANDS[1]}" "Should list branches with no arg"
}

test_amend_no_edit() {
  CAPTURED_COMMANDS=()
  g E
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git commit --amend --no-edit" "${CAPTURED_COMMANDS[1]}" "Should amend without edit"
}

test_add_amend_chain() {
  CAPTURED_COMMANDS=()
  g aE
  assert_eq 2 ${#CAPTURED_COMMANDS[@]} "Should capture two commands" && \
  assert_eq "git add ." "${CAPTURED_COMMANDS[1]}" "First should be add" && \
  assert_eq "git commit --amend --no-edit" "${CAPTURED_COMMANDS[2]}" "Second should be amend"
}

test_uncommit() {
  CAPTURED_COMMANDS=()
  g u
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git reset HEAD^ --soft" "${CAPTURED_COMMANDS[1]}" "Should soft reset"
}

test_diff_staged() {
  CAPTURED_COMMANDS=()
  g S
  assert_eq 1 ${#CAPTURED_COMMANDS[@]} "Should capture one command" && \
  assert_eq "git diff --staged" "${CAPTURED_COMMANDS[1]}" "Should show staged diff"
}

# =============================================================================
# Test Runner
# =============================================================================

echo ""
echo "${YELLOW}git-chord Unit Tests${NC}"
echo "================================"

echo ""
echo "Basic Commands:"
run_test "Empty chord runs status" test_empty_chord_runs_status
run_test "Single char: add" test_single_char_add
run_test "Single char: status" test_single_char_status
run_test "Single char: fetch" test_single_char_fetch
run_test "Single char: pull" test_single_char_pull
run_test "Single char: push" test_single_char_push
run_test "Single char: force push" test_single_char_force_push
run_test "Single char: log" test_single_char_log
run_test "Single char: stash" test_single_char_stash
run_test "Single char: stash pop" test_single_char_stash_pop

echo ""
echo "Commands with Arguments:"
run_test "Commit with positional arg" test_commit_with_positional_arg
run_test "Checkout defaults to main" test_checkout_default_to_main
run_test "Checkout with branch arg" test_checkout_with_branch_arg
run_test "New branch" test_new_branch
run_test "Delete branch" test_delete_branch
run_test "Rebase defaults to main" test_rebase_default_to_main
run_test "Rebase with branch" test_rebase_with_branch
run_test "Merge branch" test_merge_branch

echo ""
echo "Inline Quoted Arguments:"
run_test "Inline quoted commit" test_inline_quoted_commit
run_test "Inline quoted checkout" test_inline_quoted_checkout
run_test "Inline quoted new branch" test_inline_quoted_new_branch

echo ""
echo "Command Chaining:"
run_test "Add + commit chain" test_add_commit_chain
run_test "Add + commit + push chain" test_add_commit_push_chain
run_test "Checkout + pull chain" test_checkout_pull_chain
run_test "Stash + checkout + pull + pop chain" test_stash_checkout_pull_pop_chain
run_test "Mixed inline and positional" test_mixed_inline_and_positional

echo ""
echo "Multi-char Commands:"
run_test "Multi-char: push force" test_multi_char_push_force
run_test "Multi-char: push upstream" test_multi_char_push_upstream
run_test "Multi-char: rebase abort" test_multi_char_rebase_abort
run_test "Multi-char: rebase continue" test_multi_char_rebase_continue
run_test "Multi-char: stash apply" test_multi_char_stash_apply
run_test "Multi-char: stash list" test_multi_char_stash_list

echo ""
echo "Macros:"
run_test "Macro R: sync-rebase" test_macro_R_sync_rebase
run_test "Macro M: sync-merge" test_macro_M_sync_merge
run_test "Macro W: wrap-up" test_macro_W_wrap_up
run_test "Macro branch capture timing" test_macro_branch_capture
run_test "Macro arg spacing preserved" test_macro_space_arg_preserved

echo ""
echo "Error Handling:"
run_test "Unknown command fails" test_unknown_command_fails
run_test "Missing required arg fails" test_missing_required_arg_fails
run_test "Command failure stops chain" test_command_failure_stops_chain

echo ""
echo "Edge Cases:"
run_test "Branch list with no arg" test_branch_list_no_arg
run_test "Amend no edit" test_amend_no_edit
run_test "Add + amend chain" test_add_amend_chain
run_test "Uncommit" test_uncommit
run_test "Diff staged" test_diff_staged

echo ""
echo "================================"
echo "Results: ${GREEN}$TEST_PASSED passed${NC}, ${RED}$TEST_FAILED failed${NC}"
echo ""

if (( TEST_FAILED > 0 )); then
  exit 1
fi
exit 0
