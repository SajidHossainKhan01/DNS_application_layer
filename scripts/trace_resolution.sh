#!/usr/bin/env bash
# =============================================================================
# trace_resolution.sh
# Lab 1: Trace the Full DNS Resolution Path (Iterative Query)
#
# The +trace option makes dig perform an iterative DNS resolution itself,
# showing every step from root servers → TLD servers → authoritative servers.
#
# Usage: bash scripts/trace_resolution.sh [domain]
# =============================================================================
set -euo pipefail

TARGET="${1:-google.com}"
RESOLVER="1.1.1.1"

CYAN='\033[0;36m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
section() { echo -e "\n${CYAN}━━━ $* ━━━${NC}\n"; }
run()     { echo -e "${YELLOW}$ $*${NC}"; eval "$@"; echo ""; }

echo ""
echo "============================================================"
echo "  Lab 1 — DNS Iterative Resolution Trace"
echo "  Target  : $TARGET"
echo "  Resolver: $RESOLVER"
echo "============================================================"

# ── Step 1: Trace from root servers ──────────────────────────────────────────
section "Step 1: Full +trace — Root → TLD → Authoritative"
echo -e "${GREEN}Watch how the query passes through each level:${NC}"
echo -e "${GREEN}  Root Servers → .com TLD → Authoritative NS for $TARGET${NC}"
echo ""
run "dig @$RESOLVER $TARGET +trace"

# ── Step 2: Trace with additional detail ─────────────────────────────────────
section "Step 2: Trace with Query Details"
run "dig @$RESOLVER $TARGET +trace +additional"

# ── Step 3: Compare recursive vs iterative ───────────────────────────────────
section "Step 3: Recursive Query (default — one interaction)"
echo -e "${YELLOW}Recursive: client asks resolver once; resolver does all the work${NC}"
echo ""
run "dig @$RESOLVER $TARGET A"

section "Step 4: Iterative Query (manual — +trace)"
echo -e "${YELLOW}Iterative: dig queries each server in the chain itself${NC}"
echo ""
run "dig @$RESOLVER $TARGET A +trace +norecurse"

# ── Step 5: Trace MX resolution ──────────────────────────────────────────────
section "Step 5: Trace MX Record Resolution"
run "dig @$RESOLVER $TARGET MX +trace"

# ── Step 6: Trace with timing ─────────────────────────────────────────────────
section "Step 6: Trace with Query Statistics"
run "dig @$RESOLVER $TARGET +trace +stats"

echo ""
echo "============================================================"
echo "  Trace Analysis Guide"
echo "============================================================"
cat << 'EOF'

Reading the +trace output:

  .                      518400  IN  NS  a.root-servers.net.
  ↑ Root zone            ↑ TTL   ↑   ↑  ↑ Root server name
  
  com.                   172800  IN  NS  a.gtld-servers.net.
  ↑ TLD zone             ↑ TTL       ↑  ↑ TLD server name
  
  google.com.            345600  IN  NS  ns1.google.com.
  ↑ Domain zone          ↑ TTL       ↑  ↑ Authoritative NS
  
  google.com.            300     IN  A   142.250.190.4
  ↑ Final answer         ↑ TTL   ↑  ↑   ↑ IP address

Each "Received ... bytes from ... in X ms" line shows:
  - Which server responded
  - How large the response was
  - How long the query took in milliseconds

EOF
echo "============================================================"
