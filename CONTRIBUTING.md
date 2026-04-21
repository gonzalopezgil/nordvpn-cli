# Contributing to nordvpn-cli

Thanks for considering contributing! Here's how to help.

## Before you start

- **Read the README** — understand what nordvpn-cli does
- **Review SECURITY.md** — security is non-negotiable
- **Check existing issues** — avoid duplicating work
- **Pick an issue or idea** — link it in your PR

## Setup for development

```bash
git clone https://github.com/gonzalopezgil/nordvpn-cli
cd nordvpn-cli

# Make scripts executable
chmod +x nordvpn nordvpn-helper install.sh tests/test.sh tests/test_cli.sh

# Run shellcheck locally
shellcheck nordvpn nordvpn-helper install.sh tests/test.sh tests/test_cli.sh

# Run tests
bash tests/test_cli.sh
bash tests/test.sh
```

## Making changes

### Code style

- **Bash:** Use `set -euo pipefail` at the top
- **Functions:** Prefix private functions with `_` (e.g., `_get_credentials`)
- **Comments:** Explain *why*, not *what*
- **Variables:** Use `UPPERCASE` for config, `lowercase` for locals
- **Quoting:** Quote all variables: `"$var"` not `$var`
- **Shellcheck:** Fix all warnings before submitting

### Testing your changes

```bash
# Run shellcheck
shellcheck nordvpn nordvpn-helper install.sh tests/test.sh tests/test_cli.sh

# Run tests
bash tests/test_cli.sh
bash tests/test.sh

# Test manually
./nordvpn help
./nordvpn -q status
./nordvpn countries | head
```

### Commit messages

Use conventional commits:

```
feat: add WireGuard support
fix: resolve DNS timeout issue
docs: clarify credential storage
tests: add proxy command tests
chore: update dependencies
```

### PR checklist

Before submitting, ensure:

- [ ] Code passes `shellcheck`
- [ ] Tests pass: `bash tests/test_cli.sh` and `bash tests/test.sh`
- [ ] No credentials or secrets in code
- [ ] No hardcoded paths (use `$NORDVPN_DATA`, etc.)
- [ ] Commits use conventional message style
- [ ] PR description explains *what* and *why*
- [ ] README updated (if adding commands)
- [ ] SECURITY.md updated (if changing privileged operations)

## Architecture decisions

### Why bash?

Bash keeps the project a small macOS CLI with no runtime dependencies beyond standard shell tooling, and OpenVPN expects shell scripts for hooks.

### Why OpenVPN?

It's free, open source, battle-tested, and NordVPN provides `.ovpn` configs for all servers.

### Why sudoers?

Root access is needed for network operations (OpenVPN, DNS, routes). Sudoers is the standard way to grant this without requiring passwords.

### Why Keychain?

macOS Keychain is secure, encrypted, and available on every supported platform for this project.

## Ideas for contributions

### Features

- [ ] **WireGuard support** — add `--protocol wireguard` flag
- [ ] **Auto-reconnect** — monitor connection and reconnect if down
- [ ] **Health checks** — periodic ping/DNS test
- [ ] **TCP fallback** — try TCP config if UDP fails
- [ ] **Homebrew formula** — easier install on macOS
- [ ] **Shell completions** — Fish/Zsh/Bash scripts

### Infrastructure

- [ ] **GitHub Actions integration** — connection test action
- [ ] **Performance benchmarks** — track connect time over time
- [ ] **More tests** — integration tests with real VPN connection

### Documentation

- [ ] **Video tutorial** — for less technical users
- [ ] **Troubleshooting guide** — expand with common issues
- [ ] **Architecture explainer** — detailed system design
- [ ] **API reference** — if using as a library

## Reporting bugs

### When reporting a bug, include:

- **macOS version** (for example, macOS 12.1)
- **Command** that failed
- **Error message** and logs (`/tmp/nordvpn-openvpn.log`)
- **Steps to reproduce**
- **Expected vs actual behavior**

### Example:

```
OS: macOS 12.1 (M1)
Command: nordvpn connect US
Error: Connection refused
Logs: [from /tmp/nordvpn-openvpn.log]
Steps to reproduce:
  1. nordvpn connect US
  2. [wait 10s]
  3. observe connection timeout
Expected: Connected to US server
Actual: Connection timeout after 30s
```

## Code review process

1. **Automated checks** — ShellCheck and tests run automatically (GitHub Actions)
2. **Manual review** — someone will review your code for logic/security
3. **Feedback** — we'll ask questions or suggest improvements
4. **Merge** — once approved, your PR is merged!

## License

By contributing, you agree your code is licensed under MIT. See [LICENSE](LICENSE).

---

Thanks for contributing! 🎉
