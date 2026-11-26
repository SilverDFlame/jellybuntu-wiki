#!/usr/bin/env bats
# Tests for cliff.toml and the `changelog` mise task (SilverDFlame/jellybuntu#428: the
# changelog is generated from conventional commits, never hand-edited).
#
# Each test builds a throwaway git repo in $BATS_TEST_TMPDIR with commits at
# controlled committer dates, then runs the pinned git-cliff (on PATH via
# `mise run test:bats` / `mise exec -- bats`) against the repo's real
# cliff.toml. Dates are epoch arithmetic, so BSD and GNU `date` both work.

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
CONFIG="${REPO_ROOT}/cliff.toml"
PR_URL="https://github.com/SilverDFlame/jellybuntu-wiki/pull"

setup() {
  command -v git-cliff >/dev/null || skip "git-cliff not on PATH (run via mise)"
  R="$BATS_TEST_TMPDIR/repo"
  git init -q "$R"
  git -C "$R" config user.name test
  git -C "$R" config user.email test@example.invalid
  git -C "$R" config commit.gpgsign false
  NOW="$(date +%s)"
  unset CHANGELOG_DAYS
}

# commit <days-ago> <subject>: empty commit dated <days-ago> days back.
commit() {
  local ts=$((NOW - $1 * 86400))
  GIT_AUTHOR_DATE="@${ts} +0000" GIT_COMMITTER_DATE="@${ts} +0000" \
    git -C "$R" commit -q --allow-empty -m "$2"
}

cliff() {
  RUST_LOG=error git-cliff --offline --config "$CONFIG" --repository "$R"
}

@test "groups commits by conventional type in section order" {
  commit 5 "chore(ci): bump runner (#3)"
  commit 4 "fix(dns): stop the resolver flap (#2)"
  commit 3 "feat(unifi): own the controller (#1)"
  run cliff
  [ "$status" -eq 0 ]
  feat_line="$(grep -n '^## Features$' <<<"$output" | cut -d: -f1)"
  fix_line="$(grep -n '^## Bug Fixes$' <<<"$output" | cut -d: -f1)"
  chore_line="$(grep -n '^## Chores$' <<<"$output" | cut -d: -f1)"
  [ -n "$feat_line" ] && [ -n "$fix_line" ] && [ -n "$chore_line" ]
  [ "$feat_line" -lt "$fix_line" ]
  [ "$fix_line" -lt "$chore_line" ]
  # The ordering comment is stripped on render.
  [[ "$output" != *"<!--"* ]]
}

@test "entry shows date, bold scope, capitalised description and a PR link" {
  commit 2 "feat(unifi): own the controller (#483)"
  run cliff
  [ "$status" -eq 0 ]
  day="$(date -u -r $((NOW - 2 * 86400)) +%F 2>/dev/null || date -u -d "@$((NOW - 2 * 86400))" +%F)"
  [[ "$output" == *"- ${day} **unifi:** Own the controller ([#483](${PR_URL}/483))"* ]]
}

@test "default window is 30 days: a 40-day-old commit is left out" {
  commit 40 "docs: old guide (#9)"
  commit 10 "fix: recent fix (#10)"
  run cliff
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Changelog: last 30 days"* ]]
  [[ "$output" == *"Recent fix"* ]]
  [[ "$output" != *"Old guide"* ]]
  [[ "$output" != *"## Documentation"* ]]
}

@test "CHANGELOG_DAYS widens the window" {
  commit 40 "docs: old guide (#9)"
  commit 10 "fix: recent fix (#10)"
  CHANGELOG_DAYS=60 run cliff
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Changelog: last 60 days"* ]]
  [[ "$output" == *"Old guide"* ]]
  [[ "$output" == *"Recent fix"* ]]
}

@test "non-conventional subjects (merge commits) are filtered out" {
  commit 3 "feat: real change (#1)"
  commit 2 "Merge remote-tracking branch 'origin/main' into feature/x"
  commit 1 "wip"
  run cliff
  [ "$status" -eq 0 ]
  [[ "$output" == *"Real change"* ]]
  [[ "$output" != *"Merge remote-tracking"* ]]
  [[ "$output" != *"wip"* ]]
  [[ "$output" != *"## Other"* ]]
}

@test "GitHub's default revert title is listed under Reverts, not dropped" {
  commit 3 "feat: base (#1)"
  commit 1 'Revert "feat: base (#1)" (#2)'
  run cliff
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Reverts"* ]]
  [[ "$output" == *"Feat: base (#1) ([#2](${PR_URL}/2))"* ]]
}

@test "only the trailing ref is linked; an issue ref earlier in the title stays plain" {
  commit 1 "feat(routeros): upgrade both devices (#453) (#482)"
  run cliff
  [ "$status" -eq 0 ]
  [[ "$output" == *"Upgrade both devices (#453) ([#482](${PR_URL}/482))"* ]]
}

@test "a squash body does not leak into the line or break the PR link" {
  git -C "$R" commit -q --allow-empty -m "fix(dns): stop the flap (#5)" \
    -m "Details line one (#99)" -m "BREAKING CHANGE: resolver moved"
  run cliff
  [ "$status" -eq 0 ]
  [[ "$output" == *"**BREAKING** **dns:** Stop the flap ([#5](${PR_URL}/5))"* ]]
  [[ "$output" != *"Details line one"* ]]
}

@test "unknown conventional types land in Other; template syntax in a title is literal" {
  commit 2 "deps: bump libfoo (#7)"
  commit 1 "fix: braces {{ x }} stay (#6)"
  run cliff
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Other"* ]]
  [[ "$output" == *"Bump libfoo"* ]]
  [[ "$output" == *"Braces {{ x }} stay"* ]]
}

@test "breaking changes are marked" {
  commit 1 "feat(api)!: drop v1 endpoints (#7)"
  run cliff
  [ "$status" -eq 0 ]
  [[ "$output" == *"**BREAKING** **api:** Drop v1 endpoints"* ]]
}

@test "tags do not split the output into release sections" {
  commit 3 "fix: before tag (#1)"
  git -C "$R" tag v9.9.9
  commit 1 "feat: after tag (#2)"
  run cliff
  [ "$status" -eq 0 ]
  [ "$(grep -c '^# Changelog' <<<"$output")" -eq 1 ]
  [[ "$output" == *"Before tag"* ]]
  [[ "$output" == *"After tag"* ]]
  [[ "$output" != *"9.9.9"* ]]
}

@test "an empty window says so instead of printing nothing" {
  commit 40 "feat: too old (#1)"
  run cliff
  [ "$status" -eq 0 ]
  [[ "$output" == *"No changes in this window."* ]]
  [[ "$output" != *"Too old"* ]]
}

# Real-checkout smoke: assert only what holds whatever the history is. The
# wiki has no feat commits, and a shallow clone can have none in range, so a
# group heading here would fail with no code change. Grouping is covered by
# the throwaway-repo tests above, where the commits are controlled.
@test "mise run changelog prints a changelog for this repo" {
  command -v mise >/dev/null || skip "mise not on PATH"
  run --separate-stderr mise --cd "$REPO_ROOT" run changelog -- 3650
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Changelog: last 3650 days"* ]]
}

@test "mise run changelog does not echo its script (quiet = true)" {
  command -v mise >/dev/null || skip "mise not on PATH"
  run --separate-stderr mise --cd "$REPO_ROOT" run changelog
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Changelog: last 30 days"* ]]
  [[ "$output" != *"[changelog] \$"* ]]
  [[ "$stderr" != *"[changelog] \$"* ]]
}

@test "mise run changelog rejects a non-numeric window" {
  command -v mise >/dev/null || skip "mise not on PATH"
  run --separate-stderr mise --cd "$REPO_ROOT" run changelog -- abc
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"days must be a whole number"* ]]
}

@test "mise run changelog rejects a window too large to compute" {
  command -v mise >/dev/null || skip "mise not on PATH"
  run --separate-stderr mise --cd "$REPO_ROOT" run changelog -- 99999999999999999
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"up to 99999"* ]]
}
