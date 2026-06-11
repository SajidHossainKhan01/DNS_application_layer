# DNS & Application Layer Protocols

[![Platform](https://img.shields.io/badge/Platform-Linux%20%2F%20Kali-informational?logo=linux)]()
[![Tool](https://img.shields.io/badge/Tool-dig%20%7C%20Wireshark-blue)]()
[![Protocol](https://img.shields.io/badge/Protocol-DNS%20%7C%20UDP%2053%20%7C%20TCP%2053-orange)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## What This Lab Covers

This lab provides a complete hands-on understanding of **Application Layer Protocols** — with deep focus on the **Domain Name System (DNS)**. You will use real tools (`dig`, `Wireshark`) to observe, query, and analyse DNS traffic at the packet level.

| Section | Topic |
|---------|-------|
| [1. Theory](#1-application-layer--dns-theory) | OSI Layer 7, DNS protocol, server types, query flows |
| [2. dig Tool](#2-the-dig-tool--command-reference) | Full command reference with every option explained |
| [3. DNS Queries](#3-dns-queries--hands-on) | A, MX, NS, CNAME, PTR, SOA, TXT records |
| [4. Zone Transfer](#4-zone-transfer--security) | AXFR/IXFR, security risks, and mitigation |
| [5. Packet Analysis](#5-wireshark-dns-packet-analysis) | Wireshark filter, query/response header breakdown |
| [6. Recursive vs Iterative](#6-recursive-vs-iterative-queries) | Comparison, +trace walkthrough |
| [7. DNS Security](#7-dns-security-issues) | Cache poisoning, DNSSEC, DoH, DoT |
| [8. Scripts](#8-automation-scripts) | Automated dig queries, batch mode, trace scripts |

---

## Lab Environment

```
┌─────────────────────────────────────────────────────────┐
│                   Your Linux / Kali VM                  │
│                                                         │
│   Tools:  dig · nslookup · Wireshark · host             │
│                                                         │
│   ┌──────────────┐     ┌────────────────────────────┐   │
│   │  Terminal    │────►│  DNS Resolver (OS / ISP)   │   │
│   │  (dig/trace) │     │  e.g. 1.1.1.1  or  8.8.8.8│   │
│   └──────────────┘     └────────────┬───────────────┘   │
│                                     │                   │
│   ┌──────────────┐                  ▼                   │
│   │  Wireshark   │          Internet DNS Hierarchy      │
│   │  (capture    │     Root → TLD → Authoritative       │
│   │   port 53)   │                                      │
│   └──────────────┘                                      │
└─────────────────────────────────────────────────────────┘
```

### Prerequisites

```bash
# Install required tools (Kali / Ubuntu / Debian)
sudo apt update
sudo apt install -y dnsutils wireshark tshark net-tools curl

# Verify dig is available
dig -v
```

---

## 1. Application Layer & DNS Theory

### OSI Layer 7 — Application Layer

The **Application Layer (Layer 7)** is the topmost layer of the OSI model. It is the user-facing interface that provides network services directly to applications such as web browsers, email clients, and file transfer programs.

**Key responsibilities:**
- Network Service Access — interface for applications to reach network services
- Resource Sharing — distributed database access and global information lookup
- Identifying Partners — determines identity and availability of communication partners
- Protocol Syntax — defines format, semantics, and synchronisation for software-to-software communication

**Common Application Layer Protocols:**

| Protocol | Full Name | Port | Purpose |
|----------|-----------|------|---------|
| **HTTP/HTTPS** | HyperText Transfer Protocol | 80 / 443 | Web content transfer |
| **FTP** | File Transfer Protocol | 20 / 21 | File transfers |
| **SMTP** | Simple Mail Transfer Protocol | 25 / 587 | Sending email |
| **DNS** | Domain Name System | 53 (UDP/TCP) | Name-to-IP resolution |
| **SSH** | Secure Shell | 22 | Secure remote login |
| **DHCP** | Dynamic Host Configuration Protocol | 67 / 68 | Automatic IP assignment |

---

### What is DNS?

The **Domain Name System (DNS)** is the internet's phonebook. It translates human-readable domain names like `www.google.com` into machine-readable IP addresses like `142.250.190.4`.

**DNS Protocol Characteristics:**

| Property | Value |
|----------|-------|
| Transport (queries) | UDP port 53 |
| Transport (zone transfers / large) | TCP port 53 |
| Hierarchy | Distributed, hierarchical |
| Caching | TTL-based at every level |
| Security extensions | DNSSEC, DoT, DoH |

**How DNS Works — Step by Step:**

```
1. You type www.google.com in your browser
2. Browser asks the OS resolver
3. OS checks its local cache → if miss, queries configured DNS server
4. DNS server (recursive resolver) checks its cache
5. If miss: queries Root → TLD → Authoritative servers
6. Final IP returned to browser
7. Browser connects to the IP address
```

---

### DNS Server Types

| Server Type | Role | Key Function |
|------------|------|-------------|
| **Recursive Resolver** | Full query resolver | Queries DNS hierarchy on behalf of clients; caches results |
| **Root Name Server** | Top-level DNS reference | Directs queries to TLD servers; 13 clusters (A–M), globally replicated |
| **TLD Server** | Manages domain extensions | Points to authoritative servers (`.com` → Verisign, `.bd` → BTCL) |
| **Authoritative Server** | Final source of truth | Stores actual A, MX, CNAME, TXT records for a domain |
| **Forwarding Server** | Forwards queries | Applies caching or policy control; common in enterprise |
| **Caching-Only Server** | Performance booster | Stores recent lookups; no hosted zones |

---

### DNS Record Types

| Record | Purpose | Example |
|--------|---------|---------|
| **A** | IPv4 address | `google.com → 142.250.190.4` |
| **AAAA** | IPv6 address | `google.com → 2607:f8b0:4004::200e` |
| **CNAME** | Canonical name alias | `www → example.com` |
| **MX** | Mail exchange server | `example.com → mail.example.com` |
| **NS** | Authoritative name servers | `example.com → ns1.example.com` |
| **PTR** | Reverse DNS (IP → name) | `4.190.250.142.in-addr.arpa → google.com` |
| **SOA** | Start of Authority | Zone serial, refresh, retry, TTL |
| **TXT** | Text data | SPF, DKIM, domain verification |

---

## 2. The `dig` Tool — Command Reference

`dig` (Domain Information Groper) is the standard CLI tool for DNS queries on Linux. It uses the OS resolver libraries, making it accurate and reliable.

### Syntax

```
dig [OPTIONS] [NAME] [TYPE]
```

| Part | Description |
|------|-------------|
| `NAME` | Domain name or IP to query |
| `TYPE` | Record type: A, AAAA, MX, NS, CNAME, PTR, SOA, TXT, AXFR |
| `OPTIONS` | Modify output or behaviour (see below) |

### Essential Commands

```bash
# Basic A record lookup
dig google.com

# Query specific record types
dig google.com A
dig google.com AAAA
dig google.com MX
dig google.com NS
dig google.com TXT
dig google.com SOA
dig google.com CNAME

# Query a specific DNS server
dig @1.1.1.1 google.com
dig @8.8.8.8 google.com A
dig @9.9.9.9 google.com MX

# Short (concise) output
dig +short google.com
dig +short google.com MX
dig +short @1.1.1.1 google.com NS

# Trace full resolution path (iterative)
dig +trace google.com
dig @1.1.1.1 google.com +trace

# Reverse DNS lookup (IP → hostname)
dig -x 8.8.8.8
dig -x 142.250.190.4 +short

# Force TCP (instead of UDP)
dig +tcp google.com
dig +tcp @8.8.8.8 google.com A

# Show query statistics
dig +stats google.com

# Display/hide specific response sections
dig +question google.com
dig +answer google.com
dig +authority google.com
dig +additional google.com
dig +noall +answer google.com    # show ONLY the answer section
dig +noall +answer +authority google.com

# Multiple queries in one command
dig @1.1.1.1 +qr facebook.com NS google.com MX www.yahoo.com CNAME +noqr +short

# Batch mode — query from a file
dig -f domains.txt +short

# Know the root servers
dig . NS
dig . NS +short
```

### dig Options Reference

| Option | Effect |
|--------|--------|
| `+short` | Concise output — just the answer |
| `+trace` | Traces full path from root → authoritative |
| `+stats` | Shows query time and response size |
| `@server` | Use specific DNS server |
| `-x` | Reverse lookup (IP → hostname) |
| `+tcp` | Force TCP for the query |
| `+recurse` | Explicitly request recursive resolution (default) |
| `+norecurse` | Disable recursion (RD flag = 0) |
| `+question` | Show the question section |
| `+answer` | Show the answer section |
| `+authority` | Show the authority section |
| `+additional` | Show additional section |
| `+noall` | Hide all sections |
| `+nocomments` | Hide comments |
| `+nostats` | Hide statistics |
| `+nocmd` | Hide the initial command line |
| `+nocl` | Hide class in records |
| `-f file` | Batch mode — read queries from file |

---

## 3. DNS Queries — Hands-On

### Know the Root Servers

```bash
# List all 13 root server clusters
dig . NS +short

# Query root servers directly
dig @a.root-servers.net google.com
```

### Verify Name Server Records

```bash
# Find NS records for a domain
dig -t NS google.com
dig -t NS @1.1.1.1 google.com
dig -t NS +short @1.1.1.1 google.com

# Verify SOA (Start of Authority)
dig SOA google.com
dig SOA @8.8.8.8 facebook.com
```

### Common Record Lookups

```bash
# A record — IPv4 address
dig A facebook.com @1.1.1.1

# MX record — mail servers
dig MX gmail.com +short

# CNAME — alias lookup
dig CNAME www.github.com +short

# TXT — SPF / DKIM / verification records
dig TXT google.com +short

# PTR — reverse lookup
dig -x 1.1.1.1 +short
dig -x 8.8.8.8 +short
```

### Query a Non-Existent Domain

```bash
# Expect: NXDOMAIN (Non-Existent Domain) status
dig notarealadomain123456789.com
dig +short notarealadomain123456789.com

# The status field shows: NXDOMAIN
# The answer section is empty
# The authority section shows the SOA of the TLD
```

### Verify Transport Layer Protocol

```bash
# Default: UDP port 53
dig google.com                   # uses UDP by default
sudo tcpdump -i any port 53 -n   # observe in another terminal

# Force TCP port 53
dig +tcp google.com
dig +tcp @8.8.8.8 google.com
```

---

## 4. Zone Transfer & Security

### What is a Zone Transfer?

A **DNS zone transfer** replicates DNS database records from a **Primary (Master)** server to one or more **Secondary (Slave)** servers — ensuring redundancy and fault tolerance.

| Type | Name | Description |
|------|------|-------------|
| **AXFR** | Full Zone Transfer | Copies the entire zone file |
| **IXFR** | Incremental Zone Transfer | Copies only changes since last sync |

### Zone Transfer Lab Exercise

```bash
# Step 1: Find the NS records for zonetransfer.me
dig -t NS @1.1.1.1 zonetransfer.me
dig -t NS +short @1.1.1.1 zonetransfer.me

# Step 2: Attempt a zone transfer (AXFR)
# zonetransfer.me is intentionally misconfigured to demonstrate the risk
dig axfr @nsztm1.digi.ninja zonetransfer.me

# Step 3: Observe the output — full zone data exposed:
# Internal hostnames, IP addresses, MX, TXT, A records — all leaked
```

> `zonetransfer.me` is a domain intentionally left open for educational demonstration.

### Security Risks of Open Zone Transfers

If AXFR is not restricted, an attacker gains:
- All internal hostnames (e.g., `mail`, `db`, `intranet`, `vpn`)
- All IP addresses — public and private
- Network structure and relationships
- Third-party service connections

### Mitigation Controls

| Control | Purpose | Implementation |
|---------|---------|---------------|
| **Restrict Zone Transfers** | Limit AXFR to authorised IPs | BIND: `allow-transfer { 192.0.2.10; };` |
| **TSIG Authentication** | Authenticate transfers with shared keys | Configure `hmac-sha256` TSIG keys |
| **Monitor DNS Logs** | Detect unauthorised AXFR attempts | Review `/var/log/named/` or SIEM alerts |
| **Disable if Unused** | Reduce attack surface | `allow-transfer { none; };` |
| **Split DNS** | Separate internal/external zones | Internal DNS invisible from outside |
| **Network Segmentation** | Place DNS in DMZ with limited access | Firewall rules on port 53 |

---

## 5. Wireshark DNS Packet Analysis

### Capture DNS Traffic

```bash
# Terminal 1: Start capturing on port 53
sudo wireshark &
# Or via tshark:
sudo tshark -i any -f "port 53" -w dns_capture.pcap

# Terminal 2: Generate DNS traffic
dig www.google.com
dig MX gmail.com
dig -x 8.8.8.8
```

### Wireshark Filter

```
dns
```
Apply this display filter to see only DNS packets.

### DNS Query Packet — Header Fields

When you double-click a DNS query packet in Wireshark and expand `Domain Name System (query)`:

| Field | Bit Size | Description |
|-------|----------|-------------|
| **Transaction ID** | 16 bits | Matches query to response; random per query |
| **Flags** | 16 bits | QR, Opcode, AA, TC, RD, RA, Z, RCODE |
| **QR flag** | 1 bit | `0` = Query, `1` = Response |
| **Opcode** | 4 bits | `0` = Standard query, `1` = Inverse, `2` = Status |
| **RD (Recursion Desired)** | 1 bit | `1` = client wants recursive resolution |
| **Questions** | 16 bits | Number of questions in the query |
| **Answer RRs** | 16 bits | Number of answers (0 in a query) |
| **Authority RRs** | 16 bits | Number of authority records |
| **Additional RRs** | 16 bits | Number of additional records |
| **Query Name** | Variable | The domain being queried |
| **Query Type** | 16 bits | `1` = A, `28` = AAAA, `15` = MX, `2` = NS |
| **Query Class** | 16 bits | `1` = IN (Internet) |

### DNS Response Packet — Header Fields

When you double-click a DNS response packet:

| Field | Description |
|-------|-------------|
| **QR flag** | `1` = Response |
| **AA (Authoritative Answer)** | `1` = Response from authoritative server |
| **TC (Truncated)** | `1` = Response was truncated (switch to TCP) |
| **RA (Recursion Available)** | `1` = Server supports recursive queries |
| **RCODE** | `0` = No error, `3` = NXDOMAIN, `2` = SERVFAIL |
| **Answer section** | One or more Resource Records with the IP/data |
| **TTL** | Time-to-live in seconds before cache expires |
| **RDLENGTH** | Length of the RDATA field |
| **RDATA** | The actual answer (IP address, hostname, etc.) |

### Key DNS Flags Summary

| Flag | Full Name | Meaning |
|------|-----------|---------|
| **QR** | Query/Response | `0` = Query, `1` = Response |
| **AA** | Authoritative Answer | Response comes directly from the zone's authoritative server |
| **TC** | Truncated | Message was cut off; retry over TCP |
| **RD** | Recursion Desired | Client requests full recursive resolution |
| **RA** | Recursion Available | Server supports recursion |
| **AD** | Authentic Data | Response verified via DNSSEC |
| **CD** | Checking Disabled | Client accepts non-verified DNSSEC data |

---

## 6. Recursive vs Iterative Queries

### Recursive Query

The **client asks once** — the resolver does all the work and returns the final answer.

```bash
# Default dig behaviour = recursive
dig google.com

# Explicitly enable recursion
dig +recurse google.com

# Disable recursion (sends non-recursive query to server)
dig +norecurse google.com
```

**Flow:**
```
Client ──► Resolver: "What is www.example.com?"
Resolver ──► Root ──► TLD ──► Authoritative
Resolver ──► Client: "192.0.2.10"
```

### Iterative Query

The **resolver does multiple queries**, each server returning a referral until the answer is found.

```bash
# +trace forces dig to perform iterative resolution itself
dig +trace google.com
dig @1.1.1.1 google.com +trace
```

**Flow:**
```
Resolver ──► Root: "www.example.com?"
Root ──► Resolver: "Ask .com TLD at 192.0.34.166"
Resolver ──► TLD: "www.example.com?"
TLD ──► Resolver: "Ask authoritative at 203.0.113.53"
Resolver ──► Auth: "www.example.com?"
Auth ──► Resolver: "192.0.2.10"
Resolver ──► Client: "192.0.2.10"
```

### Comparison Table

| Feature | Recursive | Iterative |
|---------|-----------|-----------|
| Responsibility | Resolver finds full answer | Each server gives referral |
| Client interaction | One query only | Resolver queries multiple servers |
| Used by | Browsers, end devices | DNS resolvers ↔ DNS servers |
| Load | Higher on resolver | Distributed across servers |
| Response type | Final answer or error | Referral or final answer |
| Speed (cached) | Fast | Fast |
| Speed (uncached) | Slower (resolver does work) | Slower (multiple round-trips) |

---

## 7. DNS Security Issues

### DNS Cache Poisoning

An attacker injects a **forged DNS response** into a resolver's cache, redirecting users to malicious servers.

**How it works:**
1. Attacker sends many forged responses with guessed Transaction IDs
2. If one matches before the real response, the cache is poisoned
3. All clients using that resolver are redirected to the attacker's IP

**Mitigations:**
- **DNSSEC** — cryptographically signs DNS records; resolvers verify signatures
- **DNS over HTTPS (DoH)** — encrypts DNS queries over HTTPS (port 443)
- **DNS over TLS (DoT)** — encrypts DNS queries over TLS (port 853)
- **Source port randomisation** — makes Transaction ID guessing harder
- **0x20 encoding** — randomises query case to detect forgery

### Zone Transfer Attacks

See [Section 4](#4-zone-transfer--security) for full details.

### DNSSEC, DoH, DoT

| Technology | Purpose | Port |
|-----------|---------|------|
| **DNSSEC** | Authenticates DNS responses with signatures | 53 |
| **DoT** | Encrypts DNS over TLS | 853 |
| **DoH** | Encrypts DNS over HTTPS | 443 |

```bash
# Test DNSSEC validation
dig dnssec-tools.org +dnssec
dig sigok.verteiltesysteme.net A +dnssec    # should validate
dig sigfail.verteiltesysteme.net A +dnssec  # should fail

# Check if a domain uses DoH
dig @1.1.1.1 cloudflare-dns.com A
```

---

## 8. Automation Scripts

| Script | What It Does |
|--------|-------------|
| [`scripts/dns_queries.sh`](scripts/dns_queries.sh) | Runs all core dig queries (A, MX, NS, TXT, PTR, SOA) |
| [`scripts/zone_transfer_test.sh`](scripts/zone_transfer_test.sh) | Tests AXFR zone transfer against zonetransfer.me |
| [`scripts/trace_resolution.sh`](scripts/trace_resolution.sh) | Runs +trace for full iterative path |
| [`scripts/udp_vs_tcp.sh`](scripts/udp_vs_tcp.sh) | Compares UDP vs TCP DNS behaviour |
| [`scripts/batch_query.sh`](scripts/batch_query.sh) | Batch-queries a list of domains |
| [`scripts/batch/domains.txt`](scripts/batch/domains.txt) | Sample domain list for batch mode |
| [`scripts/dns_security_checks.sh`](scripts/dns_security_checks.sh) | Tests DNSSEC, DoH awareness, cache poisoning mitigations |

---

## Repository Structure

```
dns-application-layer-lab/
├── README.md
├── LICENSE
├── .gitignore
│
├── docs/
│   ├── application-layer-theory.md   ← OSI Layer 7 deep-dive
│   ├── dns-server-types.md           ← All 6 server types explained
│   ├── dns-record-types.md           ← A, AAAA, MX, NS, PTR, SOA, TXT, CNAME
│   ├── dns-query-flow.md             ← Recursive vs Iterative with diagrams
│   ├── zone-transfer.md              ← AXFR/IXFR, risks, mitigation
│   ├── dns-security.md               ← Cache poisoning, DNSSEC, DoH, DoT
│   └── wireshark-analysis.md         ← Packet header field reference
│
├── scripts/
│   ├── dns_queries.sh                ← Core record type queries
│   ├── zone_transfer_test.sh         ← AXFR test against zonetransfer.me
│   ├── trace_resolution.sh           ← Full iterative +trace
│   ├── udp_vs_tcp.sh                 ← Protocol comparison
│   ├── batch_query.sh                ← Batch -f mode
│   ├── dns_security_checks.sh        ← DNSSEC & security tests
│   └── batch/
│       └── domains.txt               ← Domain list for batch queries
│
├── wireshark/
│   └── dns-filters-reference.md      ← All Wireshark DNS display filters
│
└── configs/
    └── bind-zone-transfer-security.md ← BIND config examples for hardening
```

---

## Quick-Start Cheat Sheet

```bash
# 1. Know the root servers
dig . NS +short

# 2. Full A lookup
dig google.com

# 3. Specific server, specific record
dig @1.1.1.1 google.com MX +short

# 4. Trace full resolution path
dig @1.1.1.1 google.com +trace

# 5. Zone transfer test
dig axfr @nsztm1.digi.ninja zonetransfer.me

# 6. Reverse lookup
dig -x 8.8.8.8 +short

# 7. Multiple queries in one command
dig @1.1.1.1 +qr facebook.com NS google.com MX www.yahoo.com CNAME +noqr +short

# 8. Batch mode
dig -f scripts/batch/domains.txt +short

# 9. NXDOMAIN test
dig notarealadomain999.com

# 10. Force TCP
dig +tcp @8.8.8.8 google.com
```

---

## References

- [IANA Root Zone Database](https://www.iana.org/domains/root/servers)
- [RFC 1034 — DNS Concepts](https://www.rfc-editor.org/rfc/rfc1034)
- [RFC 1035 — DNS Implementation](https://www.rfc-editor.org/rfc/rfc1035)
- [RFC 5936 — DNS Zone Transfer (AXFR)](https://www.rfc-editor.org/rfc/rfc5936)
- [zonetransfer.me (educational)](https://digi.ninja/projects/zonetransferme.php)
- [dig man page](https://linux.die.net/man/1/dig)
- [Cloudflare DNS Learning](https://www.cloudflare.com/learning/dns/what-is-dns/)
- [DNSSEC Guide — ICANN](https://www.icann.org/resources/pages/dnssec-what-is-it-why-important-2019-03-05-en)

---

> ⚠️ **Disclaimer:** All DNS queries and zone transfer tests in this lab are performed against intentionally public/educational targets. Never attempt zone transfers, cache poisoning, or any DNS attack against systems you do not own.
