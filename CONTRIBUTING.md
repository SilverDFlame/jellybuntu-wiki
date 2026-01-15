# Contributing to Jellybuntu Wiki

Thank you for considering contributing to the Jellybuntu documentation!

## How to Contribute

### Documentation Improvements

1. **Fork** the repository
2. **Create a feature branch**: `git checkout -b docs/your-improvement`
3. **Make your changes** to the documentation
4. **Test locally**: `mkdocs serve` and verify changes at http://localhost:8000
5. **Run pre-commit checks**: `pre-commit run --all-files`
6. **Commit with clear messages**: Follow conventional commits format
7. **Push and create a Pull Request**

### Documentation Standards

#### Markdown Style

- Maximum line length: 120 characters
- Use ATX-style headers (`#` not underlines)
- Include blank line before/after lists and code blocks
- Use fenced code blocks with language tags

#### Code References

When referencing code from the main repository, use absolute GitHub URLs:

```markdown
See [`roles/jellyfin/tasks/main.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/jellyfin/tasks/main.yml)
```

#### Documentation Structure

- **Getting Started**: High-level guides for new users
- **Deployment**: Step-by-step procedures
- **Configuration**: Service-specific setup instructions
- **Maintenance**: Operational procedures
- **Troubleshooting**: Problem-solution format
- **Reference**: Technical specifications and API docs

### Pre-commit Hooks

We use pre-commit hooks to maintain quality:

- **markdownlint**: Markdown style consistency
- **yamllint**: YAML syntax validation (mkdocs.yml)
- **trailing-whitespace**: Clean up whitespace
- **end-of-file-fixer**: Ensure newline at EOF

Install hooks:

```bash
pip install pre-commit
pre-commit install
```

### Reporting Issues

Found incorrect or outdated documentation?
Please [open an issue](https://github.com/SilverDFlame/jellybuntu-wiki/issues/new) with:

- Page URL or file path
- Description of the problem
- Suggested correction (if known)

## Development Workflow

### Local Development

1. Clone repository:

   ```bash
   git clone git@github.com:SilverDFlame/jellybuntu-wiki.git
   cd jellybuntu-wiki
   ```

2. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

3. Run development server:

   ```bash
   mkdocs serve
   ```

4. Make changes and preview at http://localhost:8000

### Testing Changes

Before submitting:

1. Build site without errors: `mkdocs build --strict`
2. Run pre-commit: `pre-commit run --all-files`
3. Verify all links work
4. Check for spelling/grammar

## Questions?

Join discussions in the
[main repository issues](https://github.com/SilverDFlame/jellybuntu/issues)
or documentation-specific issues in this repository.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
