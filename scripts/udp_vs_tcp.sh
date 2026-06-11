#!/usr/bin/env bash
# =============================================================================
# udp_vs_tcp.sh
# Lab 1: Compare UDP and TCP Transport for DNS Queries
#
# DNS uses UDP port 53 by default for queries.
# TCP port 53 is used for:
#   - Zone transfers (AXFR/IXFR)
#   - Responses larger than 512 bytes (TC flag set)
#   - When explicitly requested with +tcp
#
# This script demonstrates both protocols and explains when each is used.
#
# Usage: bash scripts/udp_vs_tcp.sh
# Tip:   Run 'sudo tcpdump -i any port 53 -n' in another terminal to observe
# =============================================================================
set -euo pipefail

TARGET="google.com"
RESOLVER="8.8.8.8"

CYAN='\033[0;36m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
section() { echo -e "\n${CYAN}━━━ $* ━━━${NC}\n"; }
run()     { echo -e "${YELLOW}$ $*${NC}"; eval "$@"; echo ""; }

echo ""
echo "============================================================"
echo "  Lab 1 — UDP vs TCP for DNS"
echo "  Tip: Open another terminal and run:"
echo "       sudo tcpdump -i any port 53 -n"
echo "  to observe the protocol differences in real time."
echo "============================================================"

# ── UDP (default) ─────────────────────────────────────────────────────────────
section "1. Default Query — UDP port 53"
echo -e "${GREEN}DNS uses UDP by default for small queries (fast, connectionless)${NC}"
echo ""
run "dig @$RESOLVER $TARGET A"
run "dig @$RESOLVER $TARGET A +stats"
echo -e "${GREEN}Check tcpdump: you will see UDP datagram on port 53${NC}"

# ── Force TCP ─────────────────────────────────────────────────────────────────
section "2. Forced TCP Query — TCP port 53"
echo -e "${GREEN}+tcp forces dig to use TCP (3-way handshake + DNS query)${NC}"
echo ""
run "dig +tcp @$RESOLVER $TARGET A"
run "dig +tcp @$RESOLVER $TARGET A +stats"
echo -e "${GREEN}Check tcpdump: you will see SYN→SYN-ACK→ACK before the DNS data${NC}"

# ── Large response (may trigger TC flag) ─────────────────────────────────────
section "3. Query Likely to Produce Large Response"
echo -e "${GREEN}TXT and DNSKEY records can exceed 512 bytes — triggering TCP fallback${NC}"
echo ""
run "dig @$RESOLVER $TARGET TXT +stats"
run "dig +tcp @$RESOLVER $TARGET TXT +stats"

# ── When TC flag is set ───────────────────────────────────────────────────────
section "4. TC (Truncated) Flag — When DNS Falls Back to TCP"
cat << 'EOF'
The TC (Truncated) flag in the DNS header is set when a response exceeds
512 bytes over UDP (the traditional limit). RFC 6891 (EDNS0) extended this,
but many implementations still fall back to TCP when the response is large.

In Wireshark, look for:
  Flags: TC = 1   (response was cut off)
  → The client then retries the same query over TCP

Common triggers for TC=1 / TCP fallback:
  • DNSSEC records (DNSKEY, RRSIG, DS) — very large
  • TXT records with long SPF/DKIM values
  • Zone transfers (always TCP)
  • Multiple A/AAAA records for a domain

EOF

# ── EDNS0 ─────────────────────────────────────────────────────────────────────
section "5. EDNS0 — Extended DNS"
echo -e "${GREEN}EDNS0 (RFC 6891) allows UDP payloads larger than 512 bytes (up to 4096+)${NC}"
echo ""
run "dig @$RESOLVER $TARGET A +bufsize=4096"
echo -e "${GREEN}Look for 'EDNS: version: 0, flags:; udp: 4096' in the OPT pseudorecord${NC}"

# ── Protocol summary ─────────────────────────────────────────────────────────
section "Summary: When to Use UDP vs TCP"
cat << 'EOF'

  UDP port 53:
    ✅ Standard queries (A, AAAA, MX, NS, TXT, CNAME, PTR)
    ✅ Fast — no connection overhead
    ✅ Used by virtually all DNS clients by default
    ❌ Limited to ~512 bytes (without EDNS0)
    ❌ No guaranteed delivery

  TCP port 53:
    ✅ Zone transfers (AXFR, IXFR) — always TCP
    ✅ Large responses (DNSSEC, long TXT records)
    ✅ When TC flag is set in UDP response
    ✅ Reliable — connection-oriented
    ❌ Slower — TCP handshake overhead

EOF
echo "============================================================"
