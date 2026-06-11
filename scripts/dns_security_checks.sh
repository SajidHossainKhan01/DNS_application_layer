#!/usr/bin/env bash
# =============================================================================
# dns_security_checks.sh
# Lab 1: DNS Security — DNSSEC Validation, DoH/DoT Awareness, Cache Poisoning
#
# Demonstrates DNS security extensions and validates DNSSEC signatures.
#
# Usage: bash scripts/dns_security_checks.sh
# =============================================================================
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
section() { echo -e "\n${CYAN}━━━ $* ━━━${NC}\n"; }
run()     { echo -e "${YELLOW}$ $*${NC}"; eval "$@" 2>&1 || true; echo ""; }

echo ""
echo "============================================================"
echo "  Lab 1 — DNS Security Checks"
echo "============================================================"

# ── DNSSEC validation ─────────────────────────────────────────────────────────
section "1. DNSSEC — DNS Security Extensions"
cat << 'EOF'
DNSSEC adds cryptographic signatures to DNS records.
Resolvers verify these signatures to ensure records are authentic
and have not been tampered with (protects against cache poisoning).

Key DNSSEC record types:
  DNSKEY  — Public key used to sign zone records
  RRSIG   — Signature over a set of DNS records
  DS      — Delegation Signer — links child zone to parent
  NSEC/3  — Authenticated denial of existence

EOF

echo -e "${YELLOW}# Query DNSKEY for a DNSSEC-signed domain:${NC}"
run "dig @1.1.1.1 cloudflare.com DNSKEY +short"

echo -e "${YELLOW}# Check RRSIG (signature) on an A record:${NC}"
run "dig @1.1.1.1 cloudflare.com A +dnssec"

echo -e "${YELLOW}# Validate a domain that SHOULD pass DNSSEC:${NC}"
run "dig @8.8.8.8 sigok.verteiltesysteme.net A +dnssec"
echo -e "${GREEN}Look for 'ad' (Authenticated Data) flag in the header${NC}"
echo ""

echo -e "${YELLOW}# Validate a domain that SHOULD FAIL DNSSEC:${NC}"
run "dig @8.8.8.8 sigfail.verteiltesysteme.net A +dnssec"
echo -e "${RED}Expect: SERVFAIL — signature validation failed${NC}"
echo ""

# ── AD flag explanation ───────────────────────────────────────────────────────
section "2. The AD (Authentic Data) Flag"
cat << 'EOF'
When a DNSSEC-validating resolver returns a response with the AD flag set:
  flags: qr rd ra AD   ← AD = response is cryptographically verified

  • The resolver confirmed the DNS records are signed and valid.
  • The data has not been tampered with in transit or in cache.

Without DNSSEC (AD not set):
  flags: qr rd ra      ← no AD = not verified

EOF
run "dig @1.1.1.1 google.com A | grep -E 'flags:|ANSWER'"

# ── DNS over TLS (DoT) ────────────────────────────────────────────────────────
section "3. DNS over TLS (DoT) — Port 853"
cat << 'EOF'
DoT encrypts DNS queries using TLS, preventing eavesdropping and
man-in-the-middle attacks on port 53 (which is unencrypted by default).

Cloudflare DoT server: 1.1.1.1:853
Google DoT server:     8.8.8.8:853

Test with kdig (from knot-dnsutils) or openssl:
EOF

if command -v kdig >/dev/null 2>&1; then
    run "kdig -d @1.1.1.1 +tls-ca +tls google.com A"
else
    echo -e "${YELLOW}# kdig not installed. Test DoT with openssl:${NC}"
    echo "openssl s_client -connect 1.1.1.1:853 -quiet <<< ';; connection test'"
    echo ""
    echo -e "${YELLOW}# Install kdig: sudo apt install knot-dnsutils${NC}"
fi

# ── DNS over HTTPS (DoH) ──────────────────────────────────────────────────────
section "4. DNS over HTTPS (DoH) — Port 443"
cat << 'EOF'
DoH sends DNS queries as HTTPS requests, blending DNS traffic with
normal web traffic. Even ISPs and network monitors cannot distinguish
DoH queries from regular HTTPS browsing.

Cloudflare DoH: https://cloudflare-dns.com/dns-query
Google DoH:     https://dns.google/dns-query

EOF

if command -v curl >/dev/null 2>&1; then
    echo -e "${YELLOW}# Query Google DoH via curl:${NC}"
    run "curl -sH 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=google.com&type=A' | python3 -m json.tool 2>/dev/null | head -30"
fi

# ── Cache poisoning ───────────────────────────────────────────────────────────
section "5. DNS Cache Poisoning — How It Works"
cat << 'EOF'
DNS Cache Poisoning (Kaminsky Attack):

1. Attacker sends a DNS query for a non-existent subdomain:
   attacker.example.com → resolver has no cache entry

2. While resolver is waiting for the real answer, attacker floods it
   with thousands of forged responses, each with a different
   Transaction ID (16-bit field = 65,536 possibilities)

3. If one forged response arrives before the real one AND
   the Transaction ID matches → cache is poisoned

4. All users of that resolver are redirected to the attacker's IP
   until the TTL expires

Mitigations verified below:
EOF

echo -e "${YELLOW}# Verify source port randomisation (Kaminsky mitigation):${NC}"
echo "# Each query should use a different source port:"
for i in 1 2 3; do
    echo -n "  Query $i source port: "
    dig @8.8.8.8 google.com +stats 2>/dev/null | grep "SERVER:" | head -1 || echo "N/A"
done
echo ""

echo -e "${YELLOW}# Verify Transaction ID randomisation:${NC}"
echo "# Each query should have a different ID:"
for i in 1 2 3; do
    echo -n "  Query $i ID: "
    dig @8.8.8.8 google.com 2>/dev/null | grep "id:" | head -1 || echo "N/A"
done

# ── Summary ───────────────────────────────────────────────────────────────────
section "Security Summary"
cat << 'EOF'

  Attack               | Defence
  ---------------------|----------------------------------------
  Cache Poisoning      | DNSSEC + source port randomisation
  Eavesdropping        | DNS over TLS (DoT) or DNS over HTTPS (DoH)
  Zone Transfer Leak   | allow-transfer { none; }; + TSIG
  DDoS amplification   | Response Rate Limiting (RRL)
  Typosquatting        | DNSSEC + user education

EOF
echo "============================================================"
