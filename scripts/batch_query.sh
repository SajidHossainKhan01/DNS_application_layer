#!/usr/bin/env bash
# =============================================================================
# batch_query.sh
# Lab 1: Batch DNS Queries Using dig -f (File Mode)
#
# dig can read a list of domain names from a text file and query them
# one after another using the -f option. This is useful when you have
# many domains to resolve at once.
#
# Usage: bash scripts/batch_query.sh [query_file] [record_type]
# Default: queries all domains in scripts/batch/domains.txt for A records
# =============================================================================
set -euo pipefail

QUERY_FILE="${1:-scripts/batch/domains.txt}"
RECORD_TYPE="${2:-A}"
RESOLVER="1.1.1.1"

CYAN='\033[0;36m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
section() { echo -e "\n${CYAN}━━━ $* ━━━${NC}\n"; }
run()     { echo -e "${YELLOW}$ $*${NC}"; eval "$@"; echo ""; }

echo ""
echo "============================================================"
echo "  Lab 1 — Batch DNS Queries"
echo "  File    : $QUERY_FILE"
echo "  Type    : $RECORD_TYPE"
echo "  Resolver: $RESOLVER"
echo "============================================================"

# ── Check query file exists ───────────────────────────────────────────────────
if [[ ! -f "$QUERY_FILE" ]]; then
    echo "Query file not found: $QUERY_FILE"
    echo "Creating a sample file..."
    mkdir -p "$(dirname "$QUERY_FILE")"
    cat > "$QUERY_FILE" << 'EOF'
google.com
facebook.com
github.com
amazon.com
cloudflare.com
microsoft.com
apple.com
twitter.com
linkedin.com
youtube.com
EOF
    echo "Created: $QUERY_FILE"
fi

echo ""
echo "Domains in query file:"
cat "$QUERY_FILE" | nl | sed 's/^/  /'
echo ""

# ── Method 1: dig -f (batch file mode) ───────────────────────────────────────
section "Method 1: dig -f Batch File Mode"
echo -e "${GREEN}Queries all domains from the file in sequence${NC}"
echo ""
run "dig -f $QUERY_FILE +short"

# ── Method 2: Batch with specific record type ─────────────────────────────────
section "Method 2: Batch Query for $RECORD_TYPE Records"
# Create a temp file with record type appended
TMPFILE=$(mktemp)
while IFS= read -r domain || [[ -n "$domain" ]]; do
    [[ -z "$domain" || "$domain" == \#* ]] && continue
    echo "$domain $RECORD_TYPE"
done < "$QUERY_FILE" > "$TMPFILE"

run "dig -f $TMPFILE +short"
rm -f "$TMPFILE"

# ── Method 3: Batch with specific resolver ────────────────────────────────────
section "Method 3: Batch via Specific DNS Server ($RESOLVER)"
echo -e "${YELLOW}Note: @server must be set per-query in a loop when using -f${NC}"
echo ""

while IFS= read -r domain || [[ -n "$domain" ]]; do
    [[ -z "$domain" || "$domain" == \#* ]] && continue
    printf "%-30s " "$domain"
    dig "@$RESOLVER" "$domain" "$RECORD_TYPE" +short +noall +answer 2>/dev/null | \
        head -1 || echo "(no answer)"
done < "$QUERY_FILE"

# ── Method 4: MX batch ────────────────────────────────────────────────────────
section "Method 4: Batch MX Record Lookup"
echo ""
while IFS= read -r domain || [[ -n "$domain" ]]; do
    [[ -z "$domain" || "$domain" == \#* ]] && continue
    printf "MX %-28s " "$domain:"
    dig "@$RESOLVER" "$domain" MX +short +noall +answer 2>/dev/null | \
        head -1 || echo "(no MX)"
done < "$QUERY_FILE"

echo ""
echo "============================================================"
echo "  Batch query complete."
echo "  Edit scripts/batch/domains.txt to add your own domains."
echo "============================================================"
