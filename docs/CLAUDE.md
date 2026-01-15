# Documentation CLAUDE.md

Context-specific guidance for documentation authoring and maintenance.

---

## 📚 About This Repository

This is the **Jellybuntu Wiki** - a standalone documentation repository for the
[Jellybuntu infrastructure project](https://github.com/SilverDFlame/jellybuntu).

The documentation follows a **lifecycle-based organization**:

| Directory            | Purpose                           |
|----------------------|-----------------------------------|
| **Root**             | Main entry points                 |
| **deployment/**      | Step-by-step deployment guides    |
| **configuration/**   | Service and infrastructure config |
| **troubleshooting/** | Service-specific issue resolution |
| **reference/**       | Detailed technical reference      |
| **maintenance/**     | Ongoing operations                |
| **development/**     | Development workflows             |
| **archive/**         | Deprecated/legacy docs            |

**Primary Index**: [index.md](index.md)

---

## 🔗 Cross-Repository References

This wiki references code from the main Jellybuntu repository. All code references use **absolute GitHub URLs**:

```markdown
✅ Good: [`playbooks/main.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/main.yml)
✅ Good: [`roles/jellyfin/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/jellyfin)
❌ Bad: `../playbooks/main.yml` (relative path - doesn't exist in wiki)
```

**Main repository links:**

- [Main Repository](https://github.com/SilverDFlame/jellybuntu)
- [Main CLAUDE.md](https://github.com/SilverDFlame/jellybuntu/blob/main/CLAUDE.md)
- [Playbooks](https://github.com/SilverDFlame/jellybuntu/tree/main/playbooks)
- [Roles](https://github.com/SilverDFlame/jellybuntu/tree/main/roles)

---

## 🧭 When User Asks About

**Quick routing guide for common questions:**

| User Query                    | Route To                                                                      |
|-------------------------------|-------------------------------------------------------------------------------|
| "How do I..."                 | [quickstart.md](quickstart.md) or relevant guide                              |
| "What is the architecture..." | [architecture.md](architecture.md)                                            |
| "Where is service X..."       | [configuration/service-endpoints.md](configuration/service-endpoints.md)      |
| "How do I configure..."       | [configuration/service-endpoints.md](configuration/service-endpoints.md)      |
| "Playbook details..."         | [reference/playbooks.md](reference/playbooks.md)                              |
| "VM specs, IPs, resources..." | [architecture.md](architecture.md)                                            |
| "Service not working..."      | [troubleshooting/common-issues.md](troubleshooting/common-issues.md)          |
| "Specific service issue..."   | [troubleshooting/common-issues.md](troubleshooting/common-issues.md)          |

---

## ✍️ Adding New Documentation

### Choosing the Right Directory

- **deployment/** - Step-by-step setup guides (phases, initial setup, specific features)
- **configuration/** - How to configure services or infrastructure components
- **troubleshooting/** - Issue resolution guides (organized by service/domain)
- **reference/** - Deep technical documentation (APIs, playbook details, VM specs)
- **maintenance/** - Ongoing operational tasks (updates, backups, power management)
- **development/** - Contributor/developer workflows (pre-commit, testing)
- **archive/** - Deprecated content preserved for reference

### Internal Documentation Links

For links **within this wiki**, use relative paths:

```markdown
✅ Good: [Architecture Overview](../architecture.md)
✅ Good: [Service Endpoints](configuration/service-endpoints.md)
❌ Bad: [Architecture](/docs/architecture.md) (absolute path)
```

---

## 🏷️ Markdown Style Guide

### Formatting Rules

- Use emoji headers sparingly (mainly in primary docs like CLAUDE.md)
- Use `**bold**` for emphasis, not `*italics*`
- Use code blocks with language tags: \`\`\`bash, \`\`\`yaml, \`\`\`hcl
- Use tables for structured data
- Use blockquotes (`>`) for important callouts
- Use `---` for horizontal rules (section separators)

### Linting Constraints (Pre-commit Enforced)

Configuration: `.markdownlint-cli2.yaml`

**Enforced rules:**

| Rule      | Constraint                            | Notes                                       |
|-----------|---------------------------------------|---------------------------------------------|
| **MD013** | Line length max 120 chars             | Code blocks and tables excluded             |
| **MD031** | Blank lines around fenced code blocks | Add empty line before/after \`\`\` blocks   |
| **MD032** | Blank lines around lists              | Add empty line before first list item       |
| **MD040** | Code blocks need language tags        | Use \`\`\`text for generic output           |

**Relaxed rules:**

| Rule      | Setting             | Notes                                 |
|-----------|---------------------|---------------------------------------|
| **MD024** | siblings_only: true | Duplicate headings OK if not siblings |
| **MD033** | disabled            | Inline HTML allowed                   |
| **MD034** | disabled            | Bare URLs allowed                     |
| **MD041** | disabled            | First line doesn't need to be h1      |

**Ignored paths** (linting skipped):

- `**/archive/**` - Legacy documentation

**Common fixes:**

```markdown
<!-- BAD: No language tag -->
` ` `
/opt/nexus/data/
` ` `

<!-- GOOD: Language specified -->
` ` `text
/opt/nexus/data/
` ` `

<!-- BAD: No blank line before list -->
**Resolution**:
1. First step
2. Second step

<!-- GOOD: Blank line before list -->
**Resolution**:

1. First step
2. Second step
```

**Note**: Use `text` for directory structures, paths, or generic output. Use `bash` for shell commands.

---

## 📊 Documentation Health

### Key Index Files

- `index.md` - Primary documentation hub
- `quickstart.md` - 30-minute getting started guide
- `architecture.md` - Infrastructure design overview
- `reference/playbooks.md` - Complete playbook reference

---

## 🗂️ Legacy Content

Content in `archive/` is preserved for reference but no longer actively maintained:

- TrueNAS setup (replaced by Btrfs NAS)
- Portainer configuration (removed in favor of Podman)
- Homepage dashboard (removed)

**Don't delete archived docs** - they provide historical context and migration guidance.

---

**For complete documentation navigation, see [index.md](index.md)**
