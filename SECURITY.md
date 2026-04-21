# Security Policy

nordvpn-cli is designed with security as a core constraint, not an afterthought.

## Overview

### Principle of Least Privilege

The main `nordvpn` script runs as your normal user. Only **four specific operations** require root:

1. Starting/stopping OpenVPN (needs raw network access)
2. Setting DNS servers
3. Restoring routes after disconnect
4. Killing stuck OpenVPN processes

These are isolated to `nordvpn-helper`, which runs via a **scoped sudoers entry**:

```
username ALL=(root) NOPASSWD: /usr/local/libexec/nordvpn-helper *
```

This grants root access to **that specific script only** — not a blanket `sudo` escalation.

### Credentials

Credentials are stored in **macOS Keychain**:

```bash
# Service: nordvpn-openvpn
# Account: nordvpn-service
# Format: username:password
```

Access requires user interaction (Keychain prompt) unless explicitly configured otherwise.

### Auth File Cleanup

The temporary auth file (`/tmp/.nordvpn-auth-$$`) is:
- Created when connecting
- Passed to OpenVPN
- **Deleted immediately on exit** via `trap _cleanup_auth EXIT`
- **Never logged or printed**

The trap handler ensures cleanup even if the script is interrupted (Ctrl+C, SIGTERM).

### No Credentials in Scripts or CLI Arguments

- Credentials are **never hardcoded** in scripts
- They're **never passed as command-line arguments** (visible in `ps`)
- The proxy command uses **env vars internally but cleans them up**: `unset _NV_USER _NV_PASS`

### Helper Script Validation

The `nordvpn-helper` script:
- **Only accepts specific commands** via explicit `case` statement
- **No arbitrary shell execution** — no `eval`, no command interpolation
- **Validates all arguments** before passing to privileged operations
- **Logs nothing sensitive** — error messages only

```bash
case "$CMD" in
    openvpn-start|openvpn-stop|...) ... ;;
    *) echo "unknown command" >&2; exit 1 ;;
esac
```

## Threats & Mitigations

### Threat: Credential theft via process listing

**Mitigation:**
- Credentials stored in macOS Keychain
- Never passed as CLI arguments
- Auth file cleaned up via trap handler
- Proxy command clears env vars after use

### Threat: Privilege escalation

**Mitigation:**
- Sudoers entry is **scoped to the specific helper script**
- Helper script uses explicit whitelist of allowed commands
- No shell metacharacter expansion in arguments
- No `eval`, no command substitution in sensitive paths

### Threat: DNS hijacking

**Mitigation:**
- Uses NordVPN's official DNS servers: `103.86.96.100` and `103.86.99.100`
- DNS settings saved and restored on disconnect

### Threat: Route manipulation

**Mitigation:**
- Original default gateway is saved before connecting
- Routes are explicitly deleted and restored (no blanket resets)
- Gateway file (`/tmp/nordvpn-orig-gateway`) is deleted after restore

### Threat: Man-in-the-middle (MITM)

**Mitigation:**
- All API calls use HTTPS (TLS)
- NordVPN API requires no authentication (public endpoints)
- OpenVPN configs are signed by NordVPN

### Threat: Unclean disconnect

**Mitigation:**
- `trap _cleanup_auth EXIT` ensures auth file is deleted
- `trap '_cleanup_auth; exit 130' INT TERM` handles Ctrl+C
- If disconnect fails, `nordvpn fix` restores routes manually

## Audit Checklist

```bash
# 1. No credentials in code
grep -r "username\|password" nordvpn nordvpn-helper install.sh | grep -v "^#" | grep -v "echo"

# 2. No credentials in logs
grep -r "echo.*PASS\|print.*pass" nordvpn nordvpn-helper

# 3. No eval or arbitrary execution
grep -E "eval |exec \$|sh -c" nordvpn nordvpn-helper

# 4. Helper has command whitelist
grep "case.*CMD.*in" nordvpn-helper

# 5. Auth file cleanup
grep "_cleanup_auth" nordvpn

# 6. Timeouts on all curl calls
grep "curl" nordvpn nordvpn-helper install.sh | grep "max-time"

# 7. Shellcheck passes
shellcheck nordvpn nordvpn-helper install.sh tests/test.sh tests/test_cli.sh
```

## Reporting Security Issues

If you find a security vulnerability, use **GitHub private vulnerability reporting** for this repository when it is available.

If private reporting is not enabled, do **not** publish exploit details in a public issue. Share the report privately with the maintainer first, then disclose only after a fix is available.

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Code Review Before Deployment

Before deploying nordvpn-cli to production:

1. **Review the helper script** — it runs as root
2. **Check sudoers entry** — verify it's scoped correctly
3. **Test credential storage** — ensure Keychain access works correctly
4. **Run ShellCheck** — `make shellcheck`
5. **Review trap handlers** — ensure cleanup runs on exit
6. **Verify no hardcoded secrets** — `grep -r "password\|token\|api"` (should find none)

## Design Principles

1. **Minimize privileges** — only what's needed to manage VPN
2. **Defense in depth** — multiple layers of validation
3. **Explicit over implicit** — no magic, clear intent
4. **Fail safely** — errors are reported, routes restored
5. **Transparency** — code is readable and reviewable

---

For more details, see the **[README.md](README.md)** Security section.
