# nordvpn-cli

> **NordVPN CLI for macOS, Linux & Windows (WSL2) — because NordVPN forgot to ship one.**

[![macOS](https://img.shields.io/badge/macOS-12%2B-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Linux](https://img.shields.io/badge/Linux-any-FCC624?logo=linux&logoColor=white)](https://www.linux.org/)
[![Windows](https://img.shields.io/badge/Windows-WSL2-0078D6?logo=windows&logoColor=white)](https://learn.microsoft.com/en-us/windows/wsl/)
[![Bash](https://img.shields.io/badge/Bash-5%2B-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/gonzalopezgil/nordvpn-cli/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/gonzalopezgil/nordvpn-cli/actions/workflows/shellcheck.yml)

Connect, disconnect, and rotate NordVPN servers from the terminal — with JSON output, country/city filtering, and auto-rotation built for scraping workflows. Works on **macOS and Linux**.

```bash
$ nordvpn connect ES Barcelona
[nordvpn] Finding best OpenVPN server in Barcelona, Spain (ES)...
[nordvpn] Best server: Spain #847 (es847.nordvpn.com) — Barcelona — Load: 23%
[nordvpn] Connecting via OpenVPN...
[nordvpn] Connected ✓

VPN Status: Connected
Public IP:  193.239.152.11
Location:   Barcelona, Spain
Server:     es847.nordvpn.com

$ nordvpn status --json
{
  "connected": true,
  "ip": "193.239.152.11",
  "city": "Barcelona",
  "country": "ES",
  "server": "es847.nordvpn.com",
  "pid": 48291
}
```

---

## Why this exists

Official NordVPN apps are **GUI-only** and don't support CLI scripting:

| Feature | NordVPN Linux CLI | NordVPN GUI (macOS/Linux) | nordvpn-cli |
|---------|---|---|---|
| Terminal/headless support | ✓ | ✗ | ✓ |
| Server rotation scripting | ✓ | ✗ | ✓ |
| JSON output | ✗ | ✗ | ✓ |
| Country/city filtering | ✓ | ✓ | ✓ |
| HTTPS proxy URLs (no tunnel) | ✗ | ✗ | ✓ |
| Open source | ✗ | ✗ | ✓ |
| macOS support | ✗ | ✓ | ✓ |
| Works in CI/CD | Limited | ✗ | ✓ |

This tool fills the gap: **a fully scriptable NordVPN CLI for macOS and Linux, with clean error handling, JSON output, and minimal dependencies.**

---

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/gonzalopezgil/nordvpn-cli/main/install.sh | bash
```

Or from source:

```bash
git clone https://github.com/gonzalopezgil/nordvpn-cli
cd nordvpn-cli
./install.sh
```

The installer:
1. Checks for macOS/Linux and installs OpenVPN via Homebrew (macOS) or apt/yum/pacman (Linux)
2. Installs `nordvpn` to `/usr/local/bin/`
3. Installs the privileged helper to `~/.nordvpn/nordvpn-helper`
4. Configures sudoers (scoped to helper only, no blanket root access)
5. Downloads all NordVPN OpenVPN configs (~160MB, one-time)
6. Prompts for service credentials and stores them securely

---

## Quick start

```bash
nordvpn setup                # Interactive setup (credentials + test)
nordvpn connect              # Connect to Spain (default)
nordvpn connect US           # Connect to United States
nordvpn connect US "New York" # Connect to New York, US
nordvpn status               # Check connection status
nordvpn status --json        # JSON output for scripting
nordvpn disconnect           # Disconnect
nordvpn rotate               # Rotate to a new server (same country)
nordvpn cities ES            # List cities in Spain
nordvpn countries            # List all countries
nordvpn fix                  # Emergency: kill VPN + restore routes
```

---

## Commands

| Command | Description | Example |
|---|---|---|
| `setup` | Interactive setup (credentials + configs) | `nordvpn setup` |
| `connect [COUNTRY] [CITY]` | Connect to best server | `nordvpn connect ES Barcelona` |
| `disconnect` | Disconnect VPN | `nordvpn disconnect` |
| `rotate [COUNTRY] [CITY]` | Disconnect + reconnect (new server) | `nordvpn rotate US` |
| `status [--json]` | Show VPN status + public IP | `nordvpn status --json` |
| `proxy [-n N] [-c COUNTRY] [--urls]` | Get HTTPS proxy URLs (port 89, no tunnel) | `nordvpn proxy -n 5 --urls` |
| `ip [--json]` | Show current public IP + location | `nordvpn ip --json` |
| `countries` | List all available countries | `nordvpn countries` |
| `cities [COUNTRY]` | List cities in a country | `nordvpn cities US` |
| `update-configs` | Re-download server configs | `nordvpn update-configs` |
| `fix` | Emergency: kill VPN + restore routes | `nordvpn fix` |
| `help` | Show help | `nordvpn help` |

### Flags

| Flag | Description |
|---|---|
| `--quiet`, `-q` | Suppress log output (useful for scripting) |
| `--json` | Output JSON (works with `status`, `ip`) |

### Examples

```bash
# Basic usage
nordvpn connect                    # Connect to Spain (default)
nordvpn connect US                 # Connect to United States
nordvpn connect GB London          # Connect to London, UK
nordvpn connect "United States" "New York"  # Full names work too
nordvpn disconnect
nordvpn status                     # View current status

# Scripting
nordvpn status --json | jq .ip     # Extract IP as JSON
nordvpn -q rotate ES               # Rotate silently
if nordvpn status --json | jq -e '.connected' > /dev/null; then
  echo "VPN is connected"
fi

# Scraping workflow — auto-rotate every N requests
for country in ES US GB DE NL; do
  nordvpn -q rotate "$country"
  python3 scraper.py --country "$country"
done

# Monitor VPN connection
watch -n 5 'nordvpn status'
```

---

## Proxy feature (port 89, HTTPS Proxy SSL)

NordVPN servers expose HTTPS proxies on port 89 (technology: HTTP Proxy SSL). Unlike VPN tunnels, proxies work **per-request** with independent IPs — perfect for parallel scraping without routing all system traffic.

```bash
# List available proxies
nordvpn proxy -n 5
# es141.nordvpn.com:89  ES/Madrid  load:39%
# es172.nordvpn.com:89  ES/Madrid  load:27%
# es203.nordvpn.com:89  ES/Madrid  load:21%

# Get full proxy URLs (for curl, Playwright, Puppeteer, etc.)
nordvpn proxy -n 3 --urls
# https://user:pass@es141.nordvpn.com:89
# https://user:pass@es172.nordvpn.com:89
# https://user:pass@es203.nordvpn.com:89

# Filter by country
nordvpn proxy -c US -n 3

# JSON output for scripting
nordvpn proxy -n 2 --json
# [{"server":"es141.nordvpn.com","proxy":"https://...","city":"Madrid","country":"ES","load":39}, ...]

# Use with curl
PROXY=$(nordvpn proxy --urls | head -1)
curl --proxy "$PROXY" --proxy-insecure https://httpbin.org/ip

# Use with Playwright (Node.js)
const proxy = execSync('nordvpn proxy --urls').toString().trim();
const browser = await chromium.launch({ proxy: { server: proxy } });

# Python / Requests
import subprocess
import json
proxies = json.loads(subprocess.check_output(['nordvpn', 'proxy', '--json']).decode())
proxy_url = f"https://{proxies[0]['proxy']}"
requests.get(url, proxies={'https': proxy_url})
```

> **VPN tunnel vs proxy:** `connect`/`rotate` route all system traffic through a VPN tunnel (OpenVPN). `proxy` gives you per-request proxy URLs that work independently — use 5+ parallel scrapers with different IPs without touching system routes.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              nordvpn (unprivileged CLI)                 │
│              /usr/local/bin/nordvpn                     │
└────────────────────────┬────────────────────────────────┘
                         │
         ┌───────────────┼──────────────────────┐
         │               │                      │
    ┌────▼────┐  ┌──────▼──────┐  ┌───────────▼────┐
    │ NordVPN │  │  ipinfo.io  │  │   Credentials  │
    │   API   │  │  (IP geo)   │  │   (Keychain    │
    │(public) │  └─────────────┘  │  or ~/.nordvpn/│
    └────┬────┘                   │ credentials)   │
         │                        └────────────────┘
    ┌────▼──────────────────────────────────────────────┐
    │  nordvpn-helper (root via sudoers NOPASSWD)       │
    │  ~/.nordvpn/nordvpn-helper — scoped to helper only│
    └────┬──────────────────────────────────────────────┘
         │
    ┌────▼──────────────────────────────────────────────┐
    │             OpenVPN daemon                         │
    │  macOS: /opt/homebrew/opt/openvpn/sbin/openvpn   │
    │  Linux: /usr/sbin/openvpn (or system default)    │
    │  Config: ~/.nordvpn/ovpn/ovpn_udp/<server>.ovpn  │
    │  → sets routes, tun0 interface, DNS               │
    └────────────────────────────────────────────────────┘
```

**Data flow:**
1. User runs `nordvpn connect ES`
2. CLI queries NordVPN API → finds best Spanish OpenVPN server
3. Reads credentials from macOS Keychain or `~/.nordvpn/credentials`
4. Calls `sudo -n nordvpn-helper openvpn-start <config> <auth>` via scoped sudoers
5. Helper daemonizes OpenVPN → VPN tunnel established
6. CLI sets NordVPN DNS servers via helper (`networksetup` on macOS, `/etc/resolv.conf` on Linux)
7. Saves original gateway for clean disconnect

---

## Requirements

- **macOS** 12+ (Apple Silicon + Intel), **Linux** (any modern distro), or **Windows** (via WSL2)
- **OpenVPN** — installed via Homebrew (macOS) or apt/yum/pacman (Linux)
- **Python 3** — included with macOS, available in Linux repos
- **NordVPN subscription** with service credentials (from dashboard)
- **Sudo access** (needed for route/DNS management)

### Windows (WSL2)

nordvpn-cli works natively inside WSL2 using the Linux version — no additional porting needed.

```bash
# Inside WSL2 (Ubuntu, Debian, etc.)
sudo apt install openvpn curl python3
curl -fsSL https://raw.githubusercontent.com/gonzalopezgil/nordvpn-cli/main/install.sh | bash
nordvpn setup
nordvpn connect US
```

> **Note:** VPN traffic is routed within the WSL2 VM. The Windows host network is not affected. The `proxy` command works from both WSL2 and native Windows (proxies are just HTTPS URLs).

---

## Setup

### Service credentials

Get these from the NordVPN dashboard — they're **not** your account password.

1. Go to [my.nordaccount.com → Dashboard → NordVPN → Manual Configuration](https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/)
2. Click the **"Service credentials"** tab
3. Copy the **username** and **password**
4. Run `nordvpn setup` and paste them when prompted

**Credentials storage:**
- **macOS:** Encrypted in macOS Keychain (service: `nordvpn-openvpn`, account: `nordvpn-service`)
- **Linux:** Plaintext file `~/.nordvpn/credentials` with permissions `600` (readable only by owner)

To store manually (macOS):
```bash
security add-generic-password \
  -a nordvpn-service \
  -s nordvpn-openvpn \
  -w 'your-username:your-password' \
  -U
```

To verify (macOS):
```bash
security find-generic-password -a nordvpn-service -s nordvpn-openvpn -w
```

### OpenVPN configs

NordVPN provides `.ovpn` configs for all their servers. The installer downloads these (~160MB) to `~/.nordvpn/ovpn/`. To refresh:

```bash
nordvpn update-configs
```

---

## Security

### Principle of least privilege

The main `nordvpn` script runs as your normal user. Only **four specific operations** require root:

1. Starting/stopping OpenVPN (needs raw network access)
2. Setting DNS servers (`networksetup` on macOS, `/etc/resolv.conf` on Linux)
3. Restoring routes after disconnect
4. Killing stuck OpenVPN processes

These are isolated to `nordvpn-helper`, which runs via a **scoped sudoers entry**:

```
username ALL=(root) NOPASSWD: /Users/username/.nordvpn/nordvpn-helper *
```

This grants root access to **that specific script only** — not a blanket `sudo` escalation.

### Credentials

- **macOS:** Stored in the system Keychain, encrypted at rest
- **Linux:** Stored in `~/.nordvpn/credentials` with permissions `600` (only owner can read)
- **Auth file:** Temporary file (`/tmp/.nordvpn-auth-$$`) created during connect, deleted on exit via `trap`
- **Proxy command:** Uses environment variables internally but **cleans them up** (`unset _NV_USER _NV_PASS`)
- **Never logged:** Credentials are never printed to logs or stdout

### Network & DNS

- NordVPN's public API requires no authentication
- DNS is set to NordVPN's official servers: `103.86.96.100` and `103.86.99.100`
- Original gateway and DNS are saved and restored on disconnect
- Original gateway backup is deleted after restore

### No telemetry

- **Zero analytics.** No phone-home.
- **No tracking.** No user identification.
- **No telemetry.** Just OpenVPN logs to `/tmp/nordvpn-openvpn.log` (which you control).

### Code review

Before deploying, verify:

```bash
# Check for any suspicious code
grep -r "curl.*without.*max-time" .
grep -r "eval " .
grep -r "> /etc/sudoers" .

# Run ShellCheck
shellcheck nordvpn nordvpn-helper install.sh
```

---

## Testing

Run the test suite:

```bash
bash tests/test.sh
```

Tests verify (without needing a VPN connection):
- `nordvpn help` exits 0 and shows usage
- `nordvpn status` works and exits 0
- `nordvpn status --json` outputs valid JSON
- `nordvpn countries` lists countries
- `nordvpn cities ES` lists cities
- `nordvpn ip` returns current IP (requires internet, no VPN needed)
- Unknown commands exit non-zero
- `--quiet` flag suppresses output

Tests requiring credentials or an active VPN connection are **skipped** (run `nordvpn setup` to enable them).

Tests run in CI via GitHub Actions (see `.github/workflows/shellcheck.yml`).

---

## Troubleshooting

### VPN connects but internet is broken

```bash
nordvpn fix   # Kill VPN + restore original routes
```

### AUTH_FAILED in logs

```bash
# Check credentials
security find-generic-password -a nordvpn-service -s nordvpn-openvpn -w  # macOS
cat ~/.nordvpn/credentials  # Linux

# Re-store if wrong
nordvpn setup   # Re-run setup, or manually:
security add-generic-password -a nordvpn-service -s nordvpn-openvpn -w 'USER:PASS' -U
```

### Server config not found

```bash
nordvpn update-configs   # Re-download all .ovpn files
```

### View OpenVPN logs

```bash
tail -f /tmp/nordvpn-openvpn.log
```

### Sudoers not working

```bash
# Validate sudoers syntax
sudo visudo -c -f /etc/sudoers.d/nordvpn

# Test helper directly
sudo -n ~/.nordvpn/nordvpn-helper check-pid

# If permission denied, reinstall sudoers
./install.sh   # Re-run installer, it will update sudoers
```

### Check platform support

```bash
nordvpn help | head -5   # Shows which OS you're on
```

---

## Uninstall

```bash
# Disconnect if connected
nordvpn disconnect

# Remove binaries and configs
sudo rm /usr/local/bin/nordvpn /etc/sudoers.d/nordvpn
rm -rf ~/.nordvpn

# Remove stored credentials
security delete-generic-password -a nordvpn-service -s nordvpn-openvpn  # macOS only
```

---

## Contributing

Contributions welcome! Please:

1. Fork the repo and create a feature branch
2. Test locally: `bash tests/test.sh`
3. Run ShellCheck: `shellcheck nordvpn nordvpn-helper install.sh`
4. Keep changes focused — one thing per PR
5. Update the README if adding commands or changing behavior

Ideas for contributions:
- WireGuard support
- `--protocol tcp` flag (prefer TCP configs)
- Connection health monitoring / auto-reconnect
- Homebrew formula for easier install
- Fish/Zsh completions
- More granular tests

---

## License

MIT © [Gonzalo López Gil](https://github.com/gonzalopezgil)

---

*NordVPN and NordVPN's API are trademarks of Nord Security. This project is not affiliated with or endorsed by NordVPN.*
