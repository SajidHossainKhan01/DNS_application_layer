#!/usr/bin/env bash
# =============================================================================
# zone_transfer_test.sh
# Lab 1: DNS Zone Transfer (AXFR) Demonstration
#
# Uses zonetransfer.me — a domain intentionally misconfigured to allow
# zone transfers for educational purposes.
#
# Source: https://digi.ninja/projects/zonetransferme.php
#
# Usage: bash scripts/zone_transfer_test.sh
# =============================================================================
set -euo pipefail

DOMAIN="zonetransfer.me"
PUBLIC_RESOLVER="1.1.1.1"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
section() { echo -e "\n${CYAN}━━━ $* ━━━${NC}\n"; }
run()     { echo -e "${YELLOW}$ $*${NC}"; eval "$@"; echo ""; }

echo ""
echo "============================================================"
echo "  Lab 1 — DNS Zone Transfer Test"
echo "  Domain: $DOMAIN"
echo "============================================================"
echo ""
echo -e "${RED}  ⚠  Educational use only."
echo -e "  zonetransfer.me is intentionally left open for demonstration.${NC}"
echo ""

# ── Step 1: Resolve the domain ────────────────────────────────────────────────
section "Step 1: Resolve $DOMAIN using $PUBLIC_RESOLVER"
run "dig @$PUBLIC_RESOLVER $DOMAIN A +short"

# ── Step 2: Find the authoritative name servers ───────────────────────────────
section "Step 2: Identify Name Servers for $DOMAIN"
run "dig -t NS @$PUBLIC_RESOLVER $DOMAIN"
run "dig -t NS +short @$PUBLIC_RESOLVER $DOMAIN"

NS_LIST=$(dig -t NS +short @$PUBLIC_RESOLVER $DOMAIN 2>/dev/null | sed 's/\.$//')
echo -e "${GREEN}Authoritative NS servers found:${NC}"
echo "$NS_LIST" | while read -r ns; do echo "  → $ns"; done

# ── Step 3: AXFR zone transfer attempt ───────────────────────────────────────
section "Step 3: Attempt Full Zone Transfer (AXFR)"
echo -e "${YELLOW}Command: dig axfr @nsztm1.digi.ninja $DOMAIN${NC}"
echo ""

if dig axfr @nsztm1.digi.ninja "$DOMAIN" 2>/dev/null; then
    echo ""
    echo -e "${RED}  ⚠  ZONE TRANSFER SUCCEEDED — all zone data exposed!${NC}"
    echo ""
    echo "  What an attacker now knows:"
    echo "  • Every internal hostname"
    echo "  • All IP addresses (public and private)"
    echo "  • Mail servers (MX records)"
    echo "  • Network structure relationships"
    echo "  • Third-party service connections"
else
    echo -e "${GREEN}  Zone transfer refused or failed (secure configuration).${NC}"
fi

# ── Step 4: Try against the second NS ────────────────────────────────────────
section "Step 4: Try AXFR Against Second NS Server"
run "dig axfr @nsztm2.digi.ninja $DOMAIN"

# ── Step 5: IXFR (incremental) ───────────────────────────────────────────────
section "Step 5: Incremental Zone Transfer (IXFR)"
echo -e "${YELLOW}IXFR transfers only changes since a given serial number${NC}"
run "dig @nsztm1.digi.ninja $DOMAIN IXFR=1"

# ── Step 6: What secure config looks like ────────────────────────────────────
section "Step 6: Secure BIND Configuration (for reference)"
cat << 'EOF'
# /etc/named.conf — restrict zone transfers:

zone "yourdomain.com" {
    type master;
    file "/var/named/yourdomain.com.zone";

    # SECURE: only allow your secondary NS to transfer
    allow-transfer { 192.0.2.10; };

    # OR: disable entirely if no secondary
    # allow-transfer { none; };
};

# With TSIG authentication:
key "transfer-key" {
    algorithm hmac-sha256;
    secret "your-base64-secret-here==";
};

zone "yourdomain.com" {
    type master;
    allow-transfer { key transfer-key; };
};
EOF

echo ""
echo "============================================================"
echo "  Zone Transfer Test Complete."
echo "  See configs/bind-zone-transfer-security.md for full hardening guide."
echo "============================================================"
