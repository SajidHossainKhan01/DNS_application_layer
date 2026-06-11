#!/usr/bin/env bash
# =============================================================================
# dns_queries.sh
# Lab 1: Introduction to Application Layer Protocols — DNS Queries
#
# Runs all core dig queries demonstrating every DNS record type,
# server-selection, output formatting, and protocol options.
#
# Usage: bash scripts/dns_queries.sh [target_domain]
# Default target: google.com
# =============================================================================
set -euo pipefail

TARGET="${1:-google.com}"
DNS_SERVER="1.1.1.1"    # Cloudflare public resolver
ALT_SERVER="8.8.8.8"    # Google public resolver

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
section() { echo -e "\n${CYAN}━━━ $* ━━━${NC}\n"; }
run()     { echo -e "${YELLOW}$ $*${NC}"; eval "$@"; echo ""; }

echo ""
echo "============================================================"
echo "  Lab 1 — DNS Queries with dig"
echo "  Target : $TARGET"
echo "  Resolver: $DNS_SERVER"
echo "============================================================"

# ── Section 1: Root servers ───────────────────────────────────────────────────
section "1. Know the Root Servers"
run "dig . NS +short"

# ── Section 2: Basic A record ─────────────────────────────────────────────────
section "2. A Record — IPv4 Address"
run "dig $TARGET"
run "dig $TARGET A +short"
run "dig @$DNS_SERVER $TARGET A +short"

# ── Section 3: AAAA record ────────────────────────────────────────────────────
section "3. AAAA Record — IPv6 Address"
run "dig $TARGET AAAA +short"
run "dig @$ALT_SERVER $TARGET AAAA +short"

# ── Section 4: NS records ─────────────────────────────────────────────────────
section "4. NS Record — Name Servers"
run "dig -t NS $TARGET"
run "dig -t NS +short @$DNS_SERVER $TARGET"

# ── Section 5: MX records ─────────────────────────────────────────────────────
section "5. MX Record — Mail Exchange"
run "dig MX gmail.com +short"
run "dig @$DNS_SERVER MX facebook.com +short"

# ── Section 6: CNAME record ───────────────────────────────────────────────────
section "6. CNAME Record — Canonical Name Alias"
run "dig CNAME www.github.com +short"
run "dig @$DNS_SERVER CNAME www.yahoo.com +short"

# ── Section 7: TXT record ─────────────────────────────────────────────────────
section "7. TXT Record — SPF / DKIM / Verification"
run "dig TXT $TARGET +short"
run "dig TXT facebook.com +short"

# ── Section 8: SOA record ─────────────────────────────────────────────────────
section "8. SOA Record — Start of Authority"
run "dig SOA $TARGET"
run "dig SOA +short @$DNS_SERVER $TARGET"

# ── Section 9: PTR — Reverse lookup ──────────────────────────────────────────
section "9. PTR Record — Reverse DNS Lookup"
run "dig -x 8.8.8.8 +short"
run "dig -x 1.1.1.1 +short"

# ── Section 10: Query sections control ───────────────────────────────────────
section "10. Controlling Output Sections"
echo -e "${YELLOW}# Show ONLY the answer section:${NC}"
run "dig +noall +answer @$DNS_SERVER $TARGET A"

echo -e "${YELLOW}# Show answer + authority:${NC}"
run "dig +noall +answer +authority @$DNS_SERVER $TARGET NS"

echo -e "${YELLOW}# Show question section:${NC}"
run "dig +question $TARGET A"

# ── Section 11: NXDOMAIN ─────────────────────────────────────────────────────
section "11. NXDOMAIN — Querying a Non-Existent Domain"
run "dig notarealadomain123456789xyz.com"
echo -e "${GREEN}Observation: status=NXDOMAIN, empty ANSWER section, SOA in AUTHORITY${NC}"

# ── Section 12: Multiple queries in one command ───────────────────────────────
section "12. Multiple Queries in One Command"
run "dig @$DNS_SERVER +qr facebook.com NS google.com MX www.yahoo.com CNAME +noqr +short"

# ── Section 13: UDP vs TCP ────────────────────────────────────────────────────
section "13. Force TCP Instead of UDP"
run "dig +tcp @$DNS_SERVER $TARGET A"
echo -e "${GREEN}Observe: Wireshark shows TCP handshake before the DNS query${NC}"

echo ""
echo "============================================================"
echo "  All DNS queries complete."
echo "  Run 'bash scripts/zone_transfer_test.sh' for zone transfer demo."
echo "  Run 'bash scripts/trace_resolution.sh $TARGET' for +trace."
echo "============================================================"
