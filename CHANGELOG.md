# Changelog

All notable changes to nordvpn-cli are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **macOS-only support** — The CLI, helper, installer, docs, and tests now explicitly target macOS.
  - Keychain for credential storage
  - Homebrew for OpenVPN installation
  - `networksetup` for DNS management
  - `/sbin/route` for route restoration
  - Fast failure with a clear macOS-only message on unsupported operating systems

- **`nordvpn setup` command** — Interactive setup wizard
  - Prompts for service credentials
  - Downloads OpenVPN configs
  - Optional connection test
  - Stores credentials in macOS Keychain

- **Test framework** — `tests/test.sh`
  - Tests for help, status, countries, cities, ip commands
  - JSON output validation
  - Error handling verification
  - Quiet flag testing
  - GitHub Actions integration

- **Comprehensive documentation**
  - `README.md` — Complete user guide with examples
  - `SECURITY.md` — Security policy and audit checklist
  - `CONTRIBUTING.md` — Contribution guidelines
  - Expanded "How it works" architecture section
  - Comparison table (nordvpn-cli vs alternatives)

- **GitHub repository setup**
  - `.github/FUNDING.yml` — Sponsorship metadata
  - `.github/workflows/shellcheck.yml` — CI/CD pipeline
  - `.gitignore` — Comprehensive ignore patterns
  - `Makefile` — Build targets (test, shellcheck, install, uninstall)

- **Code quality**
  - ShellCheck validation (all scripts pass)
  - Consistent error handling
  - Trap handlers for cleanup on exit
  - All curl calls have `--max-time` timeouts
  - Ctrl+C handling (SIGINT trap)

### Changed

- **Helper script refactored** (`nordvpn-helper`)
  - macOS-only platform detection
  - macOS DNS management
  - macOS route management
  - Dynamic OpenVPN binary location

- **Installer refactored** (`install.sh`)
  - Requires macOS
  - Uses Homebrew for OpenVPN
  - Stores credentials in Keychain
  - Validates Python 3 availability
  - Installs the privileged helper in `/usr/local/libexec/`

- **README.md** — Major expansion
  - Updated architecture diagram
  - Added "How it works" section
  - Added proxy feature deep-dive
  - Added security section
  - Added comparison table with other solutions
  - Added troubleshooting guide

- **Error messages** — More helpful and platform-aware
  - Unsupported operating systems receive a clear macOS-only message
  - DNS setting errors mention macOS recovery commands

### Fixed

- macOS path detection
- DNS query consistency
- Route restoration robustness
- Credential storage through Keychain only
- Privileged helper location moved out of the user-writable home directory

### Removed

- Non-macOS install, runtime, documentation, and test paths.

### Security

- ✓ No credentials hardcoded in scripts
- ✓ Credentials never logged or printed
- ✓ Auth file cleaned up on exit (trap handler)
- ✓ Proxy command cleans up env vars (_NV_USER, _NV_PASS)
- ✓ Helper script whitelist of allowed commands
- ✓ All curl calls have --max-time timeouts
- ✓ Ctrl+C handling (SIGINT trap)
- ✓ Scoped sudoers entry (principle of least privilege)
- ✓ Full ShellCheck compliance

### Documentation

- Added SECURITY.md with threat model and audit checklist
- Added CONTRIBUTING.md with development setup
- Added Makefile with useful targets
- Added comprehensive architecture diagram
- Added platform comparison table
- Added proxy feature examples

---

## [1.0.0] - TBD (initial release)

### Initial Features

- `nordvpn status` — Show VPN connection status
- `nordvpn connect [COUNTRY] [CITY]` — Connect to best server
- `nordvpn disconnect` — Disconnect VPN
- `nordvpn rotate [COUNTRY] [CITY]` — Rotate to new server
- `nordvpn countries` — List available countries
- `nordvpn cities [COUNTRY]` — List cities in a country
- `nordvpn ip` — Show public IP and location
- `nordvpn proxy` — Get HTTPS proxy URLs (no tunnel needed)
- `nordvpn update-configs` — Download latest server configs
- `nordvpn fix` — Emergency recovery (kill VPN, restore routes)
- `--json` flag for JSON output
- `--quiet` flag for silent operation
- Shell installation script with sudoers setup
- macOS Keychain credential storage
- Cross-country server selection via NordVPN API
- Automatic DNS management
- Original gateway restoration on disconnect

---

## Future Roadmap

- [ ] WireGuard protocol support
- [ ] TCP protocol preference flag
- [ ] Auto-reconnect on disconnection
- [ ] Health monitoring (ping/DNS tests)
- [ ] Homebrew formula
- [ ] Shell completions (Bash/Zsh/Fish)
- [ ] Performance metrics and benchmarks
- [ ] API library (for use in other scripts)

---

[Unreleased]: https://github.com/gonzalopezgil/nordvpn-cli/tree/main
[1.0.0]: https://github.com/gonzalopezgil/nordvpn-cli/releases/tag/v1.0.0
