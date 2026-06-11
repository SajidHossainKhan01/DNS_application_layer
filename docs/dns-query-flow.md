# DNS Query Resolution Flow — Recursive vs Iterative

## Overview

When a client needs to resolve a domain name to an IP address, there are two fundamental query strategies: **recursive** and **iterative**. In practice, both are used together — the client sends a recursive query to its resolver, and the resolver uses iterative queries to walk the DNS hierarchy.

---

## Recursive Query

In a **recursive query**, the DNS client asks a resolver to find the complete answer. The resolver takes **full responsibility** for the lookup — it queries other servers as needed and only returns when it has a final answer (or an error).

### How It Works

```
Client (Browser)
    │
    │  "What is the IP of www.example.com?"  (recursive query)
    ▼
Recursive Resolver (e.g., 1.1.1.1)
    │
    │  Performs all lookups internally
    │  (Root → TLD → Authoritative)
    │
    │  "The IP is 192.0.2.10"  (final answer)
    ▼
Client (Browser)
    └──► Connects to 192.0.2.10
```

### Characteristics

| Property | Value |
|----------|-------|
| DNS flag | **RD = 1** (Recursion Desired) |
| Client effort | Minimal — one query sent, one answer received |
| Resolver effort | High — performs all sub-queries |
| Caching | Resolver caches each intermediate result |
| Response type | Final IP address or error (NXDOMAIN / SERVFAIL) |

### dig Command

```bash
# Default behaviour — recursive
dig google.com

# Explicitly request recursion (same result as above)
dig +recurse google.com

# Disable recursion — see what happens without it
dig +norecurse google.com
# Result: resolver returns a referral instead of the final answer
```

### When Recursive Queries Are Used
- **Browsers** querying the OS resolver
- **End devices** (PCs, phones) querying ISP or public DNS (8.8.8.8, 1.1.1.1)
- Any application that just needs "the answer"

---

## Iterative Query

In an **iterative query**, the DNS server does **not** fully resolve the name. Instead, it returns the best information it has — usually a **referral** to another DNS server that is closer to the answer. The querying party (usually a recursive resolver) must then contact that next server itself.

### How It Works

```
Recursive Resolver
    │
    │  "What is www.example.com?"
    ▼
Root Server (a.root-servers.net)
    │
    │  "I don't know, but ask the .com TLD server at 192.0.34.166"
    ▼
Recursive Resolver
    │
    │  "What is www.example.com?"
    ▼
.com TLD Server (192.0.34.166)
    │
    │  "I don't know, but ask the authoritative server at 203.0.113.53"
    ▼
Recursive Resolver
    │
    │  "What is www.example.com?"
    ▼
Authoritative Server (203.0.113.53)
    │
    │  "www.example.com = 192.0.2.10"  ← final answer
    ▼
Recursive Resolver
    │
    │  Returns "192.0.2.10" to the client and caches it
    ▼
Client
```

### Characteristics

| Property | Value |
|----------|-------|
| DNS flag | **RD = 0** (Recursion not desired) |
| Server effort | Low — returns referral or answer |
| Resolver effort | High — must make multiple queries |
| Caching | Each referral response can be cached |
| Response type | Referral or final answer |

### dig Command

```bash
# +trace makes dig perform iterative resolution itself
dig +trace google.com

# Trace from a specific resolver
dig @1.1.1.1 google.com +trace

# Show stats at each step
dig +trace +stats google.com
```

---

## Side-by-Side Comparison

| Feature | Recursive Query | Iterative Query |
|---------|-----------------|-----------------|
| **Responsibility** | Resolver finds the full answer | Each server gives a referral or answer |
| **Client effort** | Minimal — one query | Resolver does multiple queries |
| **Used by** | Clients, end devices | Recursive resolvers talking to DNS hierarchy |
| **Complexity for client** | Simple | Complex (resolver handles it) |
| **Load on server** | Higher on resolver | Distributed across Root, TLD, Auth |
| **Response type** | Final answer or error | Referral or final answer |
| **RD flag** | Set to 1 | Set to 0 |
| **Speed (uncached)** | Depends on resolver | Multiple RTTs |
| **Speed (cached)** | Very fast | Fast (referrals cached) |
| **Example** | Browser → ISP DNS | ISP DNS → Root → TLD → Auth |

---

## Combined Flow: How They Work Together

In reality, recursive and iterative queries are used **together** for every DNS resolution:

```
Phase 1 — Recursive (Client to Resolver):
  Browser → 1.1.1.1: "What is www.google.com?" [RD=1]
  1.1.1.1 → Browser: "142.250.190.4"           [RA=1]

Phase 2 — Iterative (Resolver to DNS Hierarchy):
  1.1.1.1 → Root:    "www.google.com?"          [RD=0]
  Root → 1.1.1.1:    "Ask .com TLD"             (referral)

  1.1.1.1 → .com TLD: "www.google.com?"         [RD=0]
  .com TLD → 1.1.1.1: "Ask ns1.google.com"      (referral)

  1.1.1.1 → ns1.google.com: "www.google.com?"   [RD=0]
  ns1.google.com → 1.1.1.1: "142.250.190.4"     (final answer)
```

---

## DNS Caching

Both query types benefit from caching. Once a resolver has looked up `www.google.com`, it stores the result for the duration of the **TTL (Time to Live)** value in the response.

```
google.com.  300  IN  A  142.250.190.4
             ↑
             TTL = 300 seconds (5 minutes)
             This answer is cached for 5 minutes
             The next query within this window is answered instantly
```

**Negative caching:** Even NXDOMAIN responses (domain doesn't exist) are cached for the duration of the SOA record's minimum TTL, preventing repeated lookups for non-existent domains.

---

## The Simple Analogy

**Recursive Query:** You ask a librarian "Where is the book on DNS?"
The librarian goes, searches all sections, comes back, and hands you the book.
You only made one request and received the final answer.

**Iterative Query:** You ask the front desk "Where is the book on DNS?"
They say "Try section B." You go to section B.
Section B says "Try shelf 12." You go to shelf 12.
Shelf 12 has the book. You found it yourself, with guidance at each step.

---

## Reading `+trace` Output

```bash
dig @1.1.1.1 google.com +trace
```

**Sample output explained:**
```
.                      518400  IN  NS  a.root-servers.net.
                                       ← Root zone NS records

;; Received 262 bytes from 1.1.1.1#53(1.1.1.1) in 5 ms
   ↑ Resolver told us which root server to query next

com.                   172800  IN  NS  a.gtld-servers.net.
                                       ← .com TLD server

;; Received 1174 bytes from 198.41.0.4#53(a.root-servers.net) in 23 ms
   ↑ Root server responded with referral to .com TLD

google.com.            345600  IN  NS  ns1.google.com.
                                       ← Authoritative NS for google.com

;; Received 492 bytes from 192.26.92.30#53(c.gtld-servers.net) in 18 ms
   ↑ .com TLD responded with referral to google.com's NS

google.com.            300     IN  A   142.250.190.4
                                       ← Final answer!

;; Received 55 bytes from 216.239.34.10#53(ns2.google.com) in 12 ms
   ↑ Authoritative server provided the IP address
```
