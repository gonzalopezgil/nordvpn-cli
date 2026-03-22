.PHONY: test shellcheck install uninstall help clean

help:
	@echo "nordvpn-cli — Makefile targets"
	@echo ""
	@echo "  make test          Run test suite"
	@echo "  make shellcheck    Run ShellCheck on all scripts"
	@echo "  make install       Run installer"
	@echo "  make uninstall     Remove installation"
	@echo "  make clean         Clean temp files"
	@echo ""

test:
	bash tests/test.sh

shellcheck:
	shellcheck nordvpn nordvpn-helper install.sh tests/test.sh

install:
	bash install.sh

uninstall:
	bash -c 'nordvpn disconnect 2>/dev/null || true'
	sudo rm -f /usr/local/bin/nordvpn /etc/sudoers.d/nordvpn
	rm -rf ~/.nordvpn
	security delete-generic-password -a nordvpn-service -s nordvpn-openvpn 2>/dev/null || true
	@echo "✓ nordvpn-cli uninstalled"

clean:
	rm -f /tmp/nordvpn-*.pid /tmp/nordvpn-*.log /tmp/.nordvpn-auth-* /tmp/test.out
	@echo "✓ Cleaned temp files"
