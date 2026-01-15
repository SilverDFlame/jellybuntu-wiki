# Jellybuntu Infrastructure Wiki

Comprehensive documentation for the Jellybuntu homelab infrastructure project.

## Overview

This repository contains the complete documentation for Jellybuntu - an Ansible-based infrastructure-as-code solution
for automating Proxmox homelab environments.

**Main Infrastructure Repository:**
[SilverDFlame/jellybuntu](https://github.com/SilverDFlame/jellybuntu)

## Documentation Structure

- **Getting Started**: Quickstart guide and architecture overview
- **Deployment**: Step-by-step deployment instructions
- **Configuration**: Service configuration guides
- **Maintenance**: Operational procedures and updates
- **Troubleshooting**: Common issues and solutions
- **Reference**: Technical reference documentation

## Viewing Documentation

The documentation is built using [MkDocs](https://www.mkdocs.org/) with the Material theme.

### Online

Visit [http://nas.discus-moth.ts.net:8082](http://nas.discus-moth.ts.net:8082) (accessible via Tailscale)

### Local Development

1. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

2. Run development server:

   ```bash
   mkdocs serve
   ```

3. View at [http://localhost:8000](http://localhost:8000)

### Build Static Site

```bash
mkdocs build
```

Output will be in the `site/` directory.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on improving documentation.

## Pre-commit Hooks

This repository uses pre-commit hooks to maintain documentation quality:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

## Cross-Repository References

Documentation references code from the main repository using absolute GitHub URLs:

```markdown
[playbooks/main.yml](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/main.yml)
```

## CI/CD

Documentation is automatically built and deployed via Woodpecker CI:

- **Trigger**: Push to `main` branch
- **Build**: MkDocs with strict mode
- **Deploy**: rsync to NAS at `/opt/docs/site/`

**Secret Required**: `ssh_ci_private_key` must be configured in Woodpecker for deployment.

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Acknowledgments

Built with [MkDocs](https://www.mkdocs.org/) and
[Material for MkDocs](https://squidfunk.github.io/mkdocs-material/).
