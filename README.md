# nordvpn-cli

> **NordVPN CLI for macOS — because NordVPN forgot to ship one.**

[![macOS](https://img.shields.io/badge/macOS-12%2B-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Bash](https://img.shields.io/badge/Bash-5%2B-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![ShellCheck](https://github.com/gonzalopezgil/nordvpn-cli/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/gonzalopezgil/nordvpn-cli/actions/workflows/shellcheck.yml)

Connect, disconnect, and rotate NordVPN servers from the terminal — with JSON output, country/city filtering, and auto-rotation built for scraping workflows.

```
$ nordvpn connect ES Barcelona
[nordvpn] Finding best OpenVPN server in Barcelona, Spain (ES)...
[nordvpn] Best server: Spain #847 (es847.nordvpn.com) — Barcelona — Load: 23%
[nordvpn] Connecting via OpenVPN...
[nordvpn] Connected ✓

VPN Status: Connected
Public IP:  193.239.152.11
Location:   Barcelona, ES
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

NordVPN on macOS is **GUI-only**. Unlike the Linux client, it ships no CLI, no daemon socket, no AppleScript support, and no documented URL scheme actions. There is no way to script it.

This means you can't:
- Automate VPN rotation for scraping pipelines
- Connect from CI/CD or remote SSH sessions
- Check connection status in scripts or monitoring tools
- Integrate NordVPN with other tooling

**nordvpn-cli** solves this by bypassing the NordVPN app entirely. It uses:
1. **NordVPN's public API** to find the best server for any country/city
2. **OpenVPN** (via Homebrew) to establish the actual VPN connection
3. **macOS Keychain** for secure credential storage
4. A minimal **privileged helper** (sudoers NOPASSWD) for the operations that require root

---

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/gonzalopezgil/nordvpn-cli/main/install.sh | bash
```

Or install from source:

```bash
git clone https://github.com/gonzalopezgil/nordvpn-cli
cd nordvpn-cli
./install.sh
```

The installer will:
1. Verify macOS and install OpenVPN via Homebrew if needed
2. Install `nordvpn` to `/usr/local/bin/`
3. Install the privileged helper to `~/.nordvpn/nordvpn-helper`
4. Configure the sudoers entry (scoped to the helper only)
5. Download all NordVPN OpenVPN configs (~160MB, one-time)
6. Prompt for your [service credentials](#credentials) and store them in Keychain

---

## Commands

| Command | Description | Example |
|---|---|---|
| `connect [COUNTRY] [CITY]` | Connect to best server | `nordvpn connect ES Barcelona` |
| `disconnect` | Disconnect VPN | `nordvpn disconnect` |
| `rotate [COUNTRY] [CITY]` | Disconnect + reconnect (new server) | `nordvpn rotate US` |
| `status [--json]` | Show VPN status + public IP | `nordvpn status --json` |
| `proxy [-n N] [-c COUNTRY]` | Get HTTPS proxy URLs (port 89) | `nordvpn proxy -n 5` |
| `ip [--json]` | Show current public IP + location | `nordvpn ip` |
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

# Scripting
nordvpn status --json | jq .ip     # Get current IP as JSON
nordvpn -q rotate ES               # Rotate silently

# Scraping workflow — auto-rotate every N requests
for country in ES US GB DE NL; do
  nordvpn -q rotate "$country"
  python3 scraper.py --country "$country"
done

# Check status in a script
if nordvpn status --json | jq -e '.connected' > /dev/null; then
  echo "VPN is up"
fi
```

### Parallel proxies (no VPN tunnel needed)

NordVPN servers expose HTTPS proxies on port 89. Use `nordvpn proxy` to get proxy URLs for parallel scraping — each proxy has a unique IP, no VPN tunnel required.

```bash
# List available proxies
nordvpn proxy -n 5
# es141.nordvpn.com:89  ES/Madrid  load:39%
# es172.nordvpn.com:89  ES/Madrid  load:27%
# es203.nordvpn.com:89  ES/Madrid  load:21%
# ...

# Get full URLs (for curl, Playwright, Puppeteer, etc.)
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
PROXY=$(nordvpn proxy --urls)
curl --proxy "$PROXY" --proxy-insecure https://httpbin.org/ip

# Use with Playwright (Node.js)
const proxy = execSync('nordvpn proxy --urls').toString().trim();
const browser = await chromium.launch({ proxy: { server: proxy } });
```

> **VPN tunnel vs proxy:** `connect`/`rotate` route all system traffic through a VPN tunnel (OpenVPN). `proxy` gives you per-request proxy URLs that work independently — you can run 5+ parallel scrapers with different IPs without touching your system routes.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      nordvpn (CLI)                      │
│                   /usr/local/bin/nordvpn                │
└────────────────────────┬────────────────────────────────┘
                         │
           ┌─────────────┼──────────────────┐
           │             │                  │
    ┌──────▼──────┐  ┌───▼──────┐   ┌──────▼──────────┐
    │ NordVPN API │  │ ipinfo.io│   │  macOS Keychain  │
    │ (public,    │  │ (IP geo) │   │  (credentials)   │
    │  no auth)   │  └──────────┘   └─────────────────-┘
    │             │
    │ /servers/   │
    │ countries   │
    │ /servers/   │
    │ recommend.  │
    └──────┬──────┘
           │  best server hostname + .ovpn config
           │
    ┌──────▼──────────────────────────────────────────────┐
    │              nordvpn-helper (privileged)             │
    │           ~/.nordvpn/nordvpn-helper                  │
    │   runs as root via sudoers NOPASSWD (scoped only)    │
    └──────┬──────────────────────────────────────────────┘
           │
    ┌──────▼──────────────────────────────────────────────┐
    │                   OpenVPN daemon                     │
    │   /opt/homebrew/opt/openvpn/sbin/openvpn             │
    │   config: ~/.nordvpn/ovpn/ovpn_udp/<server>.ovpn    │
    │   → sets routes, tun0 interface, DNS                 │
    └─────────────────────────────────────────────────────┘
```

**Data flow:**
1. User runs `nordvpn connect ES`
2. CLI queries NordVPN API → finds best Spanish OpenVPN server
3. Reads credentials from macOS Keychain
4. Calls `sudo -n nordvpn-helper openvpn-start <config> <auth>` via sudoers
5. Helper daemonizes OpenVPN → VPN tunnel established
6. CLI sets NordVPN DNS servers via helper (`networksetup`)
7. Saves original gateway for clean disconnect

---

## Requirements

- **macOS** 12 Monterey or later (Apple Silicon + Intel)
- **OpenVPN** — `brew install openvpn`
- **Python 3** — included with macOS (used for JSON parsing)
- **NordVPN subscription** with [service credentials](#credentials)

---

## Setup

### Credentials

These are **not** your NordVPN account username and password. They are separate service credentials for manual/OpenVPN connections.

1. Go to [my.nordaccount.com → Dashboard → NordVPN → Manual Configuration](https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/)
2. Click the **"Service credentials"** tab
3. Copy the **username** and **password**

The installer prompts for these and stores them in macOS Keychain. To store them manually:

```bash
security add-generic-password \
  -a nordvpn-service \
  -s nordvpn-openvpn \
  -w 'your-username:your-password' \
  -U
```

To verify they're stored:
```bash
security find-generic-password -a nordvpn-service -s nordvpn-openvpn
```

### OpenVPN configs

NordVPN provides `.ovpn` config files for all their servers. The installer downloads these (~160MB) to `~/.nordvpn/ovpn/`. To refresh them:

```bash
nordvpn update-configs
```

---

## Security

This tool is designed with security as a core constraint, not an afterthought.

### Principle of least privilege

The main `nordvpn` script runs as your normal user. Only four specific operations require root:
- Starting/stopping OpenVPN (needs raw network access)
- Modifying DNS settings (`networksetup`)
- Restoring routes after disconnect

These are isolated to `nordvpn-helper`, which runs via a scoped sudoers entry:

```
username ALL=(root) NOPASSWD: /Users/username/.nordvpn/nordvpn-helper *
```

This grants root access to **that specific script only** — not a general `sudo` escalation.

### Credentials in Keychain

Credentials are stored in macOS Keychain, never in plaintext files. The auth file passed to OpenVPN is a temporary file (`/tmp/.nordvpn-auth-$$`) that is deleted immediately after OpenVPN starts, via a `trap EXIT` handler.

### No NordVPN API authentication

The server selection API (`api.nordvpn.com/v1`) is public and requires no credentials. Your account credentials are only used for the OpenVPN connection itself.

---

## Troubleshooting

**VPN connects but internet is broken**
```bash
nordvpn fix   # Kill VPN + restore original routes
```

**AUTH_FAILED in logs**
```bash
# Check credentials are correct
security find-generic-password -a nordvpn-service -s nordvpn-openvpn -w
# Re-store if wrong:
security add-generic-password -a nordvpn-service -s nordvpn-openvpn -w 'USER:PASS' -U
```

**Server config not found**
```bash
nordvpn update-configs   # Re-download all .ovpn files
```

**View OpenVPN logs**
```bash
cat /tmp/nordvpn-openvpn.log
```

**Sudoers not working**
```bash
sudo visudo -c -f /etc/sudoers.d/nordvpn   # Validate sudoers syntax
sudo -n ~/.nordvpn/nordvpn-helper check-pid # Test helper access
```

---

## Uninstall

```bash
nordvpn disconnect
sudo rm /usr/local/bin/nordvpn /etc/sudoers.d/nordvpn
rm -rf ~/.nordvpn
security delete-generic-password -a nordvpn-service -s nordvpn-openvpn
```

---

## Contributing

Contributions welcome. Please:

1. Fork the repo and create a feature branch
2. Run `shellcheck nordvpn nordvpn-helper install.sh` before submitting
3. Keep changes focused — one thing per PR
4. Update the README if you add commands or change behaviour

Ideas for contributions:
- WireGuard support (requires different helper commands)
- `--protocol tcp` flag to prefer TCP configs
- Connection health monitoring / auto-reconnect
- Homebrew formula for easier install
- Fish/Zsh completions

---

## License

MIT © [Gonzalo López Gil](https://github.com/gonzalopezgil)

---

*NordVPN and NordVPN's API are trademarks of Nord Security. This project is not affiliated with or endorsed by NordVPN.*
