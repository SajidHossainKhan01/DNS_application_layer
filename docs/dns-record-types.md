# DNS Record Types — Complete Reference

## What is a DNS Record?

A **DNS record** (also called a Resource Record, or RR) is an entry in a DNS zone file that maps a domain name to a value. Every record has the same basic structure:

```
NAME        TTL   CLASS  TYPE   RDATA
google.com. 300   IN     A      142.250.190.4
  ↑          ↑     ↑      ↑      ↑
  Domain    Cache  Internet  Record  The actual
  name      secs   class    type    answer
```

---

## Record Type Reference

### A — IPv4 Address Record

Maps a domain name to an IPv4 address. The most common DNS record type.

```bash
dig A google.com +short
# 142.250.190.4

dig A facebook.com +short
# 157.240.3.35
```

**Zone file entry:**
```
www.example.com.  300  IN  A  192.168.1.10
```

---

### AAAA — IPv6 Address Record

Maps a domain name to an IPv6 address (four times the size of A records — hence "AAAA").

```bash
dig AAAA google.com +short
# 2607:f8b0:4004:c1b::65

dig AAAA cloudflare.com +short
```

**Zone file entry:**
```
www.example.com.  300  IN  AAAA  2001:db8::1
```

---

### CNAME — Canonical Name Record

Creates an alias from one domain name to another (the "canonical" name). The client then looks up the canonical name.

**Rules:**
- CNAME cannot coexist with other record types for the same name
- Cannot be used for the zone apex (root domain) — use ALIAS/ANAME instead
- Can chain (but avoid long chains — extra lookups)

```bash
dig CNAME www.github.com +short
# github.com.

dig CNAME www.yahoo.com +short
```

**Zone file entry:**
```
www.example.com.  300  IN  CNAME  example.com.
shop.example.com. 300  IN  CNAME  stores.shopify.com.
```

---

### MX — Mail Exchange Record

Specifies the mail server responsible for accepting email for a domain. Multiple MX records can exist with priority values (lower = higher priority).

```bash
dig MX gmail.com +short
# 10 alt1.gmail-smtp-in.l.google.com.
# 20 alt2.gmail-smtp-in.l.google.com.
# 30 alt3.gmail-smtp-in.l.google.com.

dig MX facebook.com +short
```

**Zone file entry:**
```
example.com.  300  IN  MX  10  mail1.example.com.
example.com.  300  IN  MX  20  mail2.example.com.
```

**Priority:** When sending email, the mail server tries the lowest priority number first. If unreachable, it tries higher numbers.

---

### NS — Name Server Record

Identifies the authoritative name servers for a domain. Every domain must have at least two NS records for redundancy.

```bash
dig NS google.com +short
# ns1.google.com.
# ns2.google.com.
# ns3.google.com.
# ns4.google.com.

dig NS cloudflare.com +short
```

**Zone file entry:**
```
example.com.  86400  IN  NS  ns1.example.com.
example.com.  86400  IN  NS  ns2.example.com.
```

---

### PTR — Pointer Record (Reverse DNS)

Maps an IP address back to a domain name. Used for reverse DNS lookups. PTR records live in the `in-addr.arpa` zone.

**IP address format:** The octets are reversed.
- IP `8.8.8.8` → PTR record at `8.8.8.8.in-addr.arpa.`

```bash
dig -x 8.8.8.8 +short
# dns.google.

dig -x 1.1.1.1 +short
# one.one.one.one.

dig PTR 8.8.8.8.in-addr.arpa. +short
```

**Use cases:**
- Email server verification (spam filtering checks PTR of sending IP)
- Network monitoring and logging
- Security auditing

---

### SOA — Start of Authority Record

Every DNS zone has exactly one SOA record. It contains administrative information about the zone and controls how secondary servers synchronise with the primary.

```bash
dig SOA google.com
dig SOA +short @8.8.8.8 example.com
```

**SOA fields:**
```
example.com.  3600  IN  SOA  ns1.example.com. admin.example.com. (
    2024010101  ; Serial   — incremented on every zone change
    3600        ; Refresh  — seconds before secondary checks for updates
    900         ; Retry    — seconds to wait if refresh fails
    604800      ; Expire   — seconds before secondary considers data stale
    300         ; Minimum TTL — negative caching TTL (NXDOMAIN)
)
```

| SOA Field | Description |
|-----------|-------------|
| **MNAME** | Primary nameserver for the zone |
| **RNAME** | Admin email (@ replaced with .) |
| **Serial** | Zone version — secondary uses this to detect updates |
| **Refresh** | How often secondary polls for changes |
| **Retry** | How long to wait before retrying a failed refresh |
| **Expire** | How long secondary keeps data if it can't reach primary |
| **Minimum TTL** | Default TTL for negative responses (NXDOMAIN) |

---

### TXT — Text Record

Stores arbitrary text data associated with a domain. Originally for human-readable notes, now widely used for domain verification and email security.

```bash
dig TXT google.com +short
dig TXT facebook.com +short

# Check SPF record
dig TXT gmail.com +short | grep spf

# Check domain verification tokens
dig TXT _domainkey.example.com +short
```

**Common TXT record uses:**

| Use | Example value |
|-----|--------------|
| **SPF** (email spoofing prevention) | `v=spf1 include:_spf.google.com ~all` |
| **DKIM** (email signing) | `v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3...` |
| **DMARC** (email policy) | `v=DMARC1; p=reject; rua=mailto:dmarc@example.com` |
| **Google site verification** | `google-site-verification=abc123...` |
| **Domain ownership proof** | `"MS=ms12345678"` |

---

### SRV — Service Record

Specifies the location of servers for specific services (hostname + port). Used by SIP, XMPP, and other protocols.

```bash
dig SRV _http._tcp.example.com +short
```

**Format:** `_service._protocol.name TTL IN SRV priority weight port target`
```
_sip._tcp.example.com.  300  IN  SRV  10 20 5060 sip.example.com.
```

---

### CAA — Certification Authority Authorization

Specifies which Certificate Authorities (CAs) are authorised to issue SSL/TLS certificates for a domain.

```bash
dig CAA google.com +short
# 0 issue "pki.goog"
```

---

## Complete Record Type Code Table

| Type | Code | Description |
|------|------|-------------|
| A | 1 | IPv4 address |
| NS | 2 | Name server |
| CNAME | 5 | Canonical name alias |
| SOA | 6 | Start of authority |
| PTR | 12 | Reverse DNS pointer |
| MX | 15 | Mail exchange |
| TXT | 16 | Text record |
| AAAA | 28 | IPv6 address |
| SRV | 33 | Service location |
| DS | 43 | DNSSEC delegation signer |
| RRSIG | 46 | DNSSEC signature |
| NSEC | 47 | DNSSEC next secure |
| DNSKEY | 48 | DNSSEC public key |
| CAA | 257 | CA authorisation |
| AXFR | 252 | Full zone transfer request |
| IXFR | 251 | Incremental zone transfer |
| ANY | 255 | Any record type |

---

## Quick Reference Commands

```bash
# All-in-one record lookup
dig google.com ANY +short

# Check mail configuration
dig MX gmail.com +short
dig TXT gmail.com +short | grep -E "spf|dkim|dmarc"

# Full infrastructure fingerprint
dig NS google.com +short
dig SOA google.com +noall +answer
dig A google.com +short
dig AAAA google.com +short

# Reverse lookup
dig -x 142.250.190.4 +short
```
