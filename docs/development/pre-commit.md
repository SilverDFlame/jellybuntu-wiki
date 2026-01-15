# Pre-commit Hooks

Automated code quality checks that run before every commit to catch issues early and maintain code standards.

## Overview

This project uses [pre-commit](https://pre-commit.com/) to automatically lint, format, and validate code before it's
committed to version control. This ensures consistent code quality and catches common issues early in the development
process.

### Why Pre-commit?

- **Catch errors early** - Find issues before they reach CI/CD or production
- **Consistent code style** - Automatically enforce formatting standards
- **Faster reviews** - Reviewers can focus on logic, not style
- **Automated best practices** - No need to remember all linting rules

## Quick Start

### Installation

Pre-commit is managed via mise and is automatically installed:

```bash
# Verify pre-commit is installed
mise exec -- pre-commit --version

# Install git hooks (done automatically during setup)
mise exec -- pre-commit install
```

### Usage

Pre-commit runs automatically on `git commit`. You can also run it manually:

```bash
# Run on all files
mise exec -- pre-commit run --all-files

# Run on staged files only
mise exec -- pre-commit run

# Run specific hook
mise exec -- pre-commit run ansible-lint

# Skip hooks (use sparingly!)
git commit --no-verify
```

## Configured Hooks

### General File Checks

#### trim-trailing-whitespace

- Removes trailing whitespace from all files
- Fixes automatically

#### fix-end-of-file

- Ensures files end with a newline
- Fixes automatically

#### check-yaml

- Validates YAML syntax
- Allows custom tags (Ansible compatibility)

#### check-added-large-files

- Prevents committing files > 1MB
- Protects against accidental binary commits

#### check-merge-conflict

- Detects unresolved merge conflict markers
- Prevents committing `<<<<<<<` or `>>>>>>>` markers

#### mixed-line-ending

- Enforces LF line endings
- Fixes automatically

### Ansible Linting

#### ansible-lint

- Comprehensive Ansible best practices checker
- Profile: `production` (strict)
- Config: `.ansible-lint`

#### Key checks

- FQCN format (`ansible.builtin.module`)
- Task naming conventions
- Security best practices
- Idempotency requirements

**Current status:** 27 minor violations remaining (97.8% clean)

### YAML Linting

#### yamllint

- YAML formatting and style checker
- Config: `.yamllint.yml`

#### Rules

- Max line length: 120 characters
- Indentation: 2 spaces
- Comment spacing: 1+ spaces from content
- Truthy values: Allow yes/no/on/off (Ansible compatibility)

### Terraform/OpenTofu

#### terraform_fmt

- Auto-formats `.tf` files
- Fixes automatically

#### terraform_validate

- Validates configuration syntax
- Checks for errors before apply

#### terraform_docs

- Generates/updates module README.md
- Keeps documentation in sync with code

#### terraform_checkov

- Security and compliance scanning
- Checks for common misconfigurations

### Shell Scripts

#### shellcheck

- Shell script linter
- Catches common shell scripting errors
- Follows source statements with `-x`

### Markdown

#### markdownlint-cli2

- Markdown formatting and style checker
- Config: `.markdownlint-cli2.yaml`

#### Rules

- Max line length: 120 characters
- Consistent heading styles
- Proper list formatting

## Configuration Files

### `.pre-commit-config.yaml`

Main configuration file defining all hooks:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      # ... more hooks
```

#### Key settings

- `default_install_hook_types: [pre-commit, commit-msg]` - Install both hook types
- `fail_fast: false` - Run all hooks even if one fails
- `minimum_pre_commit_version: "3.0.0"` - Require recent pre-commit

### `.ansible-lint`

Ansible-lint configuration:

```yaml
# Exclude paths
exclude_paths:
  - .git/
  - .venv/
  - "**/archive/"
  - "**/*.sops.yaml"  # SOPS-encrypted files

# Skip rules
skip_list:
  - var-naming[no-role-prefix]  # Requires extensive refactoring
```

**Profile:** `production` (strict enforcement)

### `.yamllint.yml`

YAML linting rules:

```yaml
rules:
  line-length:
    max: 120
  truthy:
    allowed-values: ['true', 'false', 'yes', 'no', 'on', 'off']
  comments-indentation: false  # ansible-lint compatibility
```

### `.markdownlint-cli2.yaml`

Markdown linting rules:

```yaml
config:
  MD013:
    line_length: 120
  MD033: false  # Allow inline HTML
```

## Common Workflows

### Making a Commit

```bash
# 1. Stage your changes
git add <files>

# 2. Try to commit (hooks run automatically)
git commit -m "Your commit message"

# 3. If hooks fail, fix issues and retry
# Pre-commit will show which checks failed and why

# 4. Some hooks auto-fix issues - just re-stage and commit
git add <auto-fixed-files>
git commit -m "Your commit message"
```

### Handling Hook Failures

#### Auto-fixed issues

```bash
# Hooks that auto-fix (trailing whitespace, EOF, terraform fmt, etc.)
# will modify files - just re-add them
git add .
git commit -m "Your message"
```

#### Manual fixes required

```bash
# View the specific error
mise exec -- pre-commit run <hook-name>

# Fix the issue in your editor
vim <file>

# Re-run to verify
mise exec -- pre-commit run <hook-name>

# Commit once passing
git commit -m "Your message"
```

### Skipping Hooks (Emergency Only)

```bash
# Skip all hooks (use sparingly!)
git commit --no-verify -m "Emergency fix"

# Better: Fix the issue or update configuration
```

## Performance

### Hook Execution Times

Typical execution times for full repository scan:

- **General checks**: ~2 seconds
- **YAML/Markdown lint**: ~3 seconds
- **Ansible-lint**: ~20 seconds (211 files)
- **Terraform checks**: ~5 seconds
- **Total**: ~30 seconds (all files)

**Per-commit:** Usually 3-10 seconds (only staged files)

### Optimization Tips

1. **Commit frequently** - Fewer files = faster checks
2. **Fix issues early** - Don't accumulate linting errors
3. **Use targeted runs** - Test specific hooks during development:

   ```bash
   mise exec -- pre-commit run ansible-lint --files playbooks/test.yml
   ```

## Troubleshooting

### Hook Not Running

#### Problem

Hooks don't execute on commit

#### Solution

```bash
# Reinstall hooks
mise exec -- pre-commit install

# Verify installation
ls -la .git/hooks/pre-commit
```

### Command Not Found

#### Problem

`pre-commit: command not found`

#### Solution

```bash
# Use mise exec wrapper
mise exec -- pre-commit run

# Or activate mise in your shell
eval "$(mise activate bash)"  # or zsh
pre-commit run
```

### Ansible-lint Taking Too Long

#### Problem

Ansible-lint is slow on large codebase

#### Solution

```bash
# Run on specific files only
mise exec -- ansible-lint playbooks/specific-file.yml

# Or temporarily disable during rapid iteration
git commit --no-verify
# Then run full checks later:
mise exec -- pre-commit run --all-files
```

### False Positives

#### Problem

Hook reports error for intentional code

#### Solution

1. **Inline disable** (preferred):

   ```yaml
   # For ansible-lint
   - name: Special case that triggers lint warning
     ansible.builtin.command: echo "test"
     changed_when: false
     # noqa: command-instead-of-shell
   ```

2. **Global exclude** (`.ansible-lint`):

   ```yaml
   exclude_paths:
     - path/to/special/file.yml
   ```

3. **Skip rule** (use sparingly):

   ```yaml
   skip_list:
     - rule-name
   ```

### Merge Conflicts in Config Files

#### Problem

`.pre-commit-config.yaml` has conflicts after merge

#### Solution

```bash
# Resolve conflicts manually
vim .pre-commit-config.yaml

# Update hook versions
mise exec -- pre-commit autoupdate

# Test configuration
mise exec -- pre-commit run --all-files
```

## Maintenance

### Updating Hooks

```bash
# Update all hooks to latest versions
mise exec -- pre-commit autoupdate

# Review changes
git diff .pre-commit-config.yaml

# Test updated hooks
mise exec -- pre-commit run --all-files

# Commit updates
git add .pre-commit-config.yaml
git commit -m "Update pre-commit hooks to latest versions"
```

### Adding New Hooks

1. Edit `.pre-commit-config.yaml`:

   ```yaml
   - repo: https://github.com/example/new-hook
     rev: v1.0.0
     hooks:
       - id: new-check
   ```

2. Install and test:

   ```bash
   mise exec -- pre-commit install
   mise exec -- pre-commit run new-check --all-files
   ```

3. Commit configuration:

   ```bash
   git add .pre-commit-config.yaml
   git commit -m "Add new-check pre-commit hook"
   ```

### Removing Hooks

1. Remove from `.pre-commit-config.yaml`
2. Test: `mise exec -- pre-commit run --all-files`
3. Commit: `git commit -m "Remove unused hook"`

## Best Practices

### Do's

✅ **Run hooks before pushing** - Catch issues early
✅ **Fix issues immediately** - Don't accumulate technical debt
✅ **Commit configuration changes** - Keep hooks in sync across team
✅ **Use inline exceptions** - Document why rules are disabled
✅ **Update hooks regularly** - Get latest bug fixes and features

### Don'ts

❌ **Don't skip hooks habitually** - Defeats the purpose
❌ **Don't commit broken code** - Even with `--no-verify`
❌ **Don't disable all rules** - Be selective about exclusions
❌ **Don't ignore hook failures** - Investigate and fix root cause
❌ **Don't add large files** - Use `.gitignore` or Git LFS

## Integration with CI/CD

Pre-commit hooks provide fast local feedback, but CI/CD provides the safety net:

**Local (pre-commit):**

- Fast feedback (seconds)
- Catches common issues
- Can be bypassed if needed

**CI/CD (GitHub Actions, etc.):**

- Enforces standards (cannot bypass)
- Runs on all branches
- Gates merges to main

**Recommended CI/CD setup:**

```yaml
# .github/workflows/lint.yml
- name: Run pre-commit
  run: |
    mise exec -- pre-commit run --all-files
```

## Hook Reference

| Hook | Type | Auto-fix | Speed | Purpose |
|------|------|----------|-------|---------|
| trailing-whitespace | General | ✅ | Fast | Remove trailing spaces |
| end-of-file-fixer | General | ✅ | Fast | Ensure final newline |
| check-yaml | General | ❌ | Fast | Validate YAML syntax |
| check-merge-conflict | General | ❌ | Fast | Detect conflict markers |
| ansible-lint | Ansible | ❌ | Slow | Ansible best practices |
| yamllint | YAML | ❌ | Fast | YAML style |
| terraform_fmt | Terraform | ✅ | Fast | Format Terraform |
| terraform_validate | Terraform | ❌ | Medium | Validate Terraform |
| shellcheck | Shell | ❌ | Fast | Shell script linting |
| markdownlint | Markdown | ❌ | Fast | Markdown style |

## See Also

- [Pre-commit Documentation](https://pre-commit.com/)
- [Ansible-lint Rules](https://ansible.readthedocs.io/projects/lint/rules/)
- [TRaSH Guides](https://trash-guides.info/) - Media automation best practices
- [Mise Documentation](https://mise.jdx.dev/) - Tool version management
