# DNS Server Types — Complete Reference

## Overview

A **DNS Server** is any computer that implements the DNS protocol, listens for DNS requests on port 53, and responds according to its configured role. Different server types form the hierarchical DNS infrastructure that makes the internet work.

---

## The DNS Hierarchy

```
                    ┌─────────────────┐
                    │  Root Servers   │  ← 13 clusters (A–M)
                    │   (. zone)      │     worldwide replicas
                    └────────┬────────┘
                             │  delegates to
          ┌──────────────────┼──────────────────┐
          ▼                  ▼                  ▼
    ┌──────────┐       ┌──────────┐       ┌──────────┐
    │  .com    │       │  .org    │       │  .bd     │
    │  TLD     │       │  TLD     │       │  TLD     │
    └────┬─────┘       └──────────┘       └──────────┘
         │  delegates to
    ┌────▼─────────────────────┐
    │  Authoritative NS for    │
    │  google.com, amazon.com  │
    │  example.com, etc.       │
    └──────────────────────────┘
```

---

## 1. Root Name Servers

**Role:** Top of the DNS hierarchy. They do not store domain-specific records but know the address of every TLD server.

**Key facts:**
- There are **13 root server clusters**, labelled A through M
- Each letter represents a cluster of many servers distributed globally (anycast routing)
- Operated by organisations including ICANN, Verisign, NASA, the US Army, and others
- Root servers answer with referrals: "I don't know, but ask the `.com` TLD server"

**The 13 root server clusters:**

| Label | Operator | Address |
|-------|---------|---------|
| A | Verisign | 198.41.0.4 |
| B | USC-ISI | 199.9.14.201 |
| C | Cogent | 192.33.4.12 |
| D | University of Maryland | 199.7.91.13 |
| E | NASA | 192.203.230.10 |
| F | Internet Systems Consortium | 192.5.5.241 |
| G | US DoD | 192.112.36.4 |
| H | US Army | 198.97.190.53 |
| I | Netnod | 192.36.148.17 |
| J | Verisign | 192.58.128.30 |
| K | RIPE NCC | 193.0.14.129 |
| L | ICANN | 199.7.83.42 |
| M | WIDE Project | 202.12.27.33 |

```bash
# See all root servers
dig . NS +short

# Query a root server directly
dig @a.root-servers.net google.com
```

---

## 2. TLD (Top-Level Domain) Name Servers

**Role:** Manage information for top-level domains — the last part of a domain name (`.com`, `.org`, `.net`, `.bd`, etc.).

**Function:**
- Store and serve data about second-level domains within their TLD
- Know which authoritative nameserver handles each registered domain
- Return referrals: "I don't know the IP, but ask the authoritative server for `google.com`"

**TLD categories:**

| Type | Examples | Description |
|------|---------|-------------|
| **gTLD** | `.com`, `.org`, `.net`, `.info` | Generic top-level domains |
| **ccTLD** | `.bd`, `.uk`, `.us`, `.jp` | Country-code top-level domains |
| **sTLD** | `.edu`, `.gov`, `.mil` | Sponsored TLDs (restricted use) |
| **New gTLD** | `.shop`, `.app`, `.cloud` | Newer additions since 2014 |

**TLD Operators:**

| TLD | Operator |
|-----|---------|
| `.com` | Verisign |
| `.org` | Public Interest Registry |
| `.net` | Verisign |
| `.bd` | Bangladesh Telecommunications Company Limited (BTCL) |
| `.uk` | Nominet |

```bash
# Find the TLD server for .com
dig @a.root-servers.net com NS +short

# Find TLD server for .bd
dig @a.root-servers.net bd NS +short
```

---

## 3. Authoritative Name Servers

**Role:** The **final source of truth** for a domain. They hold the actual DNS zone file with all records for that domain.

**Key behaviours:**
- Answer queries about domains they host with definitive records
- Do **not** perform recursive lookups — they only answer what they know
- Come in two subtypes: Primary (Master) and Secondary (Slave)

### Primary (Master) Server
- Holds the **original zone file**
- All DNS record changes are made here
- Initiates zone transfers to secondary servers

### Secondary (Slave) Server
- Holds a **read-only copy** of the zone file
- Receives updates via AXFR (full) or IXFR (incremental) zone transfer
- Provides redundancy and load distribution

**Example zone file records:**
```
; Zone: example.com
example.com.    300  IN  A     192.168.1.10
www             300  IN  CNAME example.com.
mail            300  IN  A     192.168.1.20
example.com.    300  IN  MX 10 mail.example.com.
example.com.    300  IN  NS    ns1.example.com.
example.com.    300  IN  NS    ns2.example.com.
```

```bash
# Find authoritative NS for a domain
dig NS google.com +short

# Query the authoritative server directly
dig @ns1.google.com google.com A
```

---

## 4. Recursive Resolver

**Role:** The workhorse of the DNS system. Accepts queries from client devices and resolves them fully by querying the DNS hierarchy.

**Key behaviours:**
- Receives queries from clients (browsers, apps)
- Takes **full responsibility** for resolving the domain name
- Queries root → TLD → authoritative servers on the client's behalf
- **Caches** results to serve future queries faster (respecting TTL)
- Returns the final IP address (or error) to the client

**Common public recursive resolvers:**

| Provider | IPv4 | IPv6 | Features |
|---------|------|------|---------|
| Cloudflare | 1.1.1.1, 1.0.0.1 | 2606:4700:4700::1111 | Privacy-focused, fast |
| Google | 8.8.8.8, 8.8.4.4 | 2001:4860:4860::8888 | Reliable, widely used |
| Quad9 | 9.9.9.9 | 2620:fe::fe | Security filtering |
| OpenDNS | 208.67.222.222 | — | Content filtering |

```bash
# Use Cloudflare resolver
dig @1.1.1.1 google.com A

# Use Google resolver
dig @8.8.8.8 google.com MX +short

# Disable recursion to see what an authoritative response looks like
dig @8.8.8.8 google.com +norecurse
```

---

## 5. Forwarding Name Server

**Role:** Passes DNS queries to another DNS server (usually a recursive resolver) instead of resolving them directly.

**Use cases:**
- Corporate environments: forward external queries to Google/Cloudflare; resolve internal names locally
- Apply DNS filtering policies (block malware/adult content domains)
- Log and monitor all DNS requests centrally
- Reduce direct internet exposure of internal DNS servers

**Example BIND config:**
```
options {
    forwarders {
        8.8.8.8;
        1.1.1.1;
    };
    forward only;
};

zone "internal.company.com" {
    type master;
    file "/etc/bind/internal.zone";
};
```

---

## 6. Caching-Only Name Server

**Role:** Does not host any zone files. Purely stores and serves cached results of previous lookups.

**Key behaviours:**
- Stores DNS responses for the duration of their TTL
- Reduces repeated queries to root/TLD/authoritative servers
- Improves query performance for the local network
- Entries expire automatically when TTL reaches zero

**TTL (Time To Live):**
```
google.com.   300  IN  A  142.250.190.4
              ↑
              TTL in seconds — this record stays in cache for 5 minutes
```

---

## Server Type Summary

| Type | Hosts Zones? | Does Recursion? | Caches? | Primary Use |
|------|-------------|----------------|---------|-------------|
| Root | . zone only | No — referrals only | No | Top of hierarchy |
| TLD | TLD zones | No — referrals only | No | Domain registration |
| Authoritative | Yes | No | No | Holds actual records |
| Recursive Resolver | No | Yes | Yes | Client-facing resolution |
| Forwarding | No | No — forwards | Optional | Policy control |
| Caching-Only | No | No | Yes | Performance |
