# DNS Security Issues — Cache Poisoning, DNSSEC, DoH, DoT

## The Security Problem with Basic DNS

Basic DNS (RFC 1035, 1987) was designed for a **small, trusted network**. It has no built-in authentication, no encryption, and no integrity verification. Every DNS query and response travels in plaintext over UDP port 53, making it vulnerable to several attack classes.

---

## 1. DNS Cache Poisoning (Kaminsky Attack)

### What It Is

DNS cache poisoning injects **forged DNS responses** into a resolver's cache. Once poisoned, every client using that resolver is redirected to the attacker's IP address — without any visible warning.

### How the Kaminsky Attack Works (2008)

Dan Kaminsky discovered a practical method to poison DNS caches at scale:

```
Step 1: Attacker triggers a lookup for a non-existent subdomain
        (e.g., random12345.target.com)
        → Resolver has no cache entry; must query authoritative server

Step 2: Before the real answer arrives, attacker floods the resolver
        with thousands of forged responses:
        "random12345.target.com = ATTACKER_IP
         Also, target.com NS = attacker-ns.evil.com
         Transaction ID = ????"

Step 3: If one forged response has the correct Transaction ID (16-bit,
        so only 65,536 possibilities) AND arrives before the real response...

Step 4: Cache is poisoned.
        All queries for target.com now resolve to ATTACKER_IP.
        TTL determines how long the poisoning lasts.
```

### Visual Flow

```
Attacker                    Resolver                Real Auth Server
    │                           │                          │
    │  "Resolve                 │                          │
    │   rand.target.com"───────►│                          │
    │                           │──── Query ──────────────►│
    │                           │                          │
    │  Flood: 65535 forged      │                   (slow response)
    │  responses with           │
    │  different TXIDs ────────►│
    │                           │
    │  One TXID matches! ──────►│ ← Cache POISONED
    │                           │
    │                    Client │
    │                      ────►│ "target.com?"
    │                           │
    │                           └──► "ATTACKER_IP"  ← wrong!
```

### Impact
- **Credential theft** — users connect to fake login pages
- **Malware delivery** — legitimate software update servers redirected to malware
- **Phishing at scale** — entire ISP customer base affected with one poisoning

---

## 2. DNSSEC — DNS Security Extensions

### What DNSSEC Provides

DNSSEC adds **cryptographic signatures** to DNS records, allowing resolvers to verify that responses are authentic and have not been tampered with.

| Problem Solved | How |
|---------------|-----|
| Cache poisoning | Resolvers reject responses with invalid signatures |
| Man-in-the-Middle | Forged responses fail signature verification |
| Data integrity | Any modification to a signed record is detectable |

**DNSSEC does NOT provide:**
- Confidentiality (queries are still visible in plaintext)
- Protection against DDoS
- Availability guarantees

### DNSSEC Record Types

| Record | Purpose |
|--------|---------|
| **DNSKEY** | Public key used to sign zone records |
| **RRSIG** | Cryptographic signature over a Resource Record set |
| **DS** | Delegation Signer — links a child zone's key to the parent zone |
| **NSEC** | Next Secure — proves a domain does NOT exist (prevents NXDOMAIN spoofing) |
| **NSEC3** | Hashed version of NSEC — prevents zone enumeration |

### How DNSSEC Works

```
Zone Owner (DNS Admin):
  1. Generates a Zone Signing Key (ZSK) pair
  2. Signs all records in the zone with ZSK private key → RRSIG records
  3. Generates a Key Signing Key (KSK) pair
  4. Signs the DNSKEY record with KSK → creates the DS record
  5. Submits DS record to parent zone (TLD) → establishes chain of trust

Resolver (Validation):
  1. Receives DNS response with RRSIG
  2. Fetches DNSKEY from the authoritative server
  3. Verifies RRSIG using DNSKEY public key
  4. Verifies DNSKEY using DS record from parent zone
  5. Verifies DS using parent's DNSKEY
  6. Chain goes up to the root zone (trust anchor)
  7. If all signatures valid → sets AD flag in response
  8. If any signature fails → SERVFAIL (rejects response)
```

### Testing DNSSEC

```bash
# Request DNSSEC validation
dig @1.1.1.1 cloudflare.com A +dnssec

# Look for: flags: qr rd ra AD
# AD = Authenticated Data — DNSSEC verified

# Check DNSKEY record
dig DNSKEY cloudflare.com +short

# Check RRSIG (signature)
dig A cloudflare.com +dnssec | grep RRSIG

# Test with known-good DNSSEC domain
dig @8.8.8.8 sigok.verteiltesysteme.net A +dnssec
# Should return: AD flag set, valid RRSIG

# Test with intentionally broken DNSSEC
dig @8.8.8.8 sigfail.verteiltesysteme.net A +dnssec
# Should return: SERVFAIL — invalid signature
```

---

## 3. DNS over TLS (DoT)

### What It Solves

Standard DNS queries travel in **plaintext over UDP port 53**. Anyone on the network path (ISP, router, coffee-shop Wi-Fi operator) can see every domain you query.

DoT wraps DNS queries in a **TLS 1.3 tunnel**, encrypting the entire DNS conversation.

| Property | Value |
|----------|-------|
| Port | **853** (TCP) |
| Encryption | TLS 1.2 / 1.3 |
| Standard | RFC 7858 |
| Authentication | Server certificate verification |

### DoT Flow

```
Client                          DoT Server (1.1.1.1:853)
  │                                      │
  │──── TLS ClientHello ───────────────► │
  │◄─── TLS ServerHello + Certificate ── │
  │──── TLS Finished ──────────────────► │
  │                                      │
  │──── Encrypted DNS Query ───────────► │  (no one can see what you asked)
  │◄─── Encrypted DNS Response ───────── │
```

### Testing DoT

```bash
# Install kdig (from knot-dnsutils)
sudo apt install knot-dnsutils

# Query via DoT (Cloudflare)
kdig -d @1.1.1.1 +tls-ca +tls google.com A

# Query via DoT (Google)
kdig -d @8.8.8.8 +tls-ca +tls google.com A

# Test the TLS connection manually
openssl s_client -connect 1.1.1.1:853
```

---

## 4. DNS over HTTPS (DoH)

### What It Solves

DoH sends DNS queries as **standard HTTPS requests** on **port 443**. This has two advantages:
1. Traffic is encrypted (same as DoT)
2. DNS queries are **indistinguishable** from regular HTTPS traffic — even deep packet inspection cannot identify them as DNS

| Property | Value |
|----------|-------|
| Port | **443** (TCP) |
| Encryption | TLS via HTTPS |
| Standard | RFC 8484 |
| Format | JSON or DNS wire format over HTTP/2 |

### DoH Endpoints

| Provider | URL |
|---------|-----|
| Cloudflare | `https://cloudflare-dns.com/dns-query` |
| Google | `https://dns.google/dns-query` |
| Quad9 | `https://dns.quad9.net/dns-query` |
| NextDNS | `https://dns.nextdns.io/` |

### Testing DoH

```bash
# Query via Cloudflare DoH (JSON format)
curl -sH "accept: application/dns-json" \
  "https://cloudflare-dns.com/dns-query?name=google.com&type=A" \
  | python3 -m json.tool

# Query via Google DoH
curl -sH "accept: application/dns-json" \
  "https://dns.google/resolve?name=github.com&type=MX" \
  | python3 -m json.tool

# DNS wire format over HTTPS
curl -s "https://cloudflare-dns.com/dns-query?dns=q80BAAABAAAAAAAAA3d3dwdleGFtcGxlA2NvbQAAAQAB" \
  -H "accept: application/dns-message" | xxd | head
```

---

## 5. DoH vs DoT Comparison

| Feature | DoT | DoH |
|---------|-----|-----|
| Port | 853 | 443 |
| Protocol | TLS over TCP | HTTPS (TLS + HTTP/2) |
| Identifiable as DNS? | Yes (port 853 is DNS-only) | No (blends with HTTPS) |
| Censorship resistance | Lower (port 853 blockable) | Higher (port 443 hard to block) |
| Performance | Slightly faster | Slightly more overhead (HTTP headers) |
| Enterprise visibility | Easier to monitor | Harder to inspect |
| Browser support | No | Yes (Firefox, Chrome built-in) |
| Standard | RFC 7858 | RFC 8484 |

---

## 6. Attack vs Defence Summary

| Attack | Mechanism | Defence |
|--------|-----------|---------|
| **Cache poisoning** | Forged responses with guessed TXID | DNSSEC + source port randomisation |
| **Eavesdropping** | Sniff plaintext UDP/53 traffic | DoT or DoH encryption |
| **MITM on DNS** | Intercept and modify DNS responses | DNSSEC signature validation |
| **Zone transfer leak** | AXFR exposes full zone | `allow-transfer { none; }` + TSIG |
| **DDoS amplification** | Small DNS query → large response | Response Rate Limiting (RRL) |
| **NXDOMAIN hijacking** | ISP redirects failed lookups to ads | DNSSEC negative records (NSEC) |
| **Typosquatting** | Register similar domains | DNSSEC + user awareness |
| **DNS tunnelling** | Encode data in DNS queries for C2 | DNS traffic monitoring + RPZ |
