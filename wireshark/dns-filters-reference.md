# Wireshark DNS Packet Analysis — Filter Reference

## Quick Start

1. Open Wireshark and select your network interface
2. Apply the display filter: `dns`
3. In a terminal, run: `dig www.google.com`
4. Observe the DNS query and response packets in Wireshark

---

## Essential Display Filters

```
# Show all DNS traffic
dns

# Show only DNS queries (QR flag = 0)
dns.flags.response == 0

# Show only DNS responses (QR flag = 1)
dns.flags.response == 1

# Filter by query type
dns.qry.type == 1       # A record
dns.qry.type == 28      # AAAA record
dns.qry.type == 15      # MX record
dns.qry.type == 2       # NS record
dns.qry.type == 5       # CNAME record
dns.qry.type == 6       # SOA record
dns.qry.type == 16      # TXT record
dns.qry.type == 12      # PTR record
dns.qry.type == 252     # AXFR (zone transfer)

# Filter by domain name
dns.qry.name == "google.com"
dns.qry.name contains "google"

# Show NXDOMAIN responses (domain not found)
dns.flags.rcode == 3

# Show SERVFAIL responses
dns.flags.rcode == 2

# Show truncated responses (TC flag set)
dns.flags.truncated == 1

# Show authoritative answers (AA flag)
dns.flags.authoritative == 1

# Show DNSSEC-validated responses (AD flag)
dns.flags.authenticated == 1

# Show responses over TCP (zone transfers)
tcp.port == 53

# Show DNS over UDP only
udp.port == 53

# Combine filters
dns && ip.addr == 8.8.8.8
dns && dns.flags.response == 1 && dns.flags.rcode == 0
dns.qry.name contains "google" && dns.flags.response == 0
```

---

## DNS Query Packet — Field-by-Field

```
Domain Name System (query)
├── Transaction ID: 0xABCD          ← 16-bit random ID; matched to response
├── Flags: 0x0100 Standard query
│   ├── QR: 0 (Query)               ← 0=query, 1=response
│   ├── Opcode: 0 (Standard)        ← query type; 0=standard
│   ├── AA: 0                       ← not set in queries
│   ├── TC: 0                       ← not truncated
│   ├── RD: 1 (Recursion desired)   ← client wants recursive resolution
│   ├── RA: 0                       ← not set in queries
│   ├── Z: 0                        ← reserved
│   ├── AD: 0                       ← DNSSEC not requested yet
│   └── CD: 0                       ← checking not disabled
├── Questions: 1
├── Answer RRs: 0
├── Authority RRs: 0
├── Additional RRs: 1               ← OPT record (EDNS0)
└── Queries
    ├── Name: www.google.com
    ├── Type: A (1)                 ← record type requested
    └── Class: IN (1)               ← Internet class
```

---

## DNS Response Packet — Field-by-Field

```
Domain Name System (response)
├── Transaction ID: 0xABCD          ← matches the query ID
├── Flags: 0x8180 Standard query response, No error
│   ├── QR: 1 (Response)            ← this is a response
│   ├── Opcode: 0 (Standard)
│   ├── AA: 0                       ← 1 if from authoritative server
│   ├── TC: 0                       ← 1 if response was truncated
│   ├── RD: 1                       ← recursion was requested
│   ├── RA: 1                       ← server supports recursion
│   ├── Z: 0
│   ├── AD: 0                       ← 1 if DNSSEC validated
│   ├── CD: 0
│   └── RCODE: 0 (No error)         ← 3=NXDOMAIN, 2=SERVFAIL
├── Questions: 1
├── Answer RRs: 6                   ← number of answer records
├── Authority RRs: 0
├── Additional RRs: 1
├── Queries
│   ├── Name: www.google.com
│   ├── Type: A (1)
│   └── Class: IN (1)
└── Answers
    ├── Name: www.google.com
    ├── Type: A (1)
    ├── Class: IN (1)
    ├── Time to live: 300            ← seconds until cache expires
    ├── Data length: 4
    └── Address: 142.250.190.4       ← the IP address answer
```

---

## DNS Flag Reference

| Flag | Bit | Meaning (0 / 1) |
|------|-----|-----------------|
| **QR** | 1 | 0 = Query / 1 = Response |
| **AA** | 1 | 0 = Not authoritative / 1 = Authoritative answer |
| **TC** | 1 | 0 = Not truncated / 1 = Response was truncated |
| **RD** | 1 | 0 = Recursion not desired / 1 = Recursion desired |
| **RA** | 1 | 0 = Recursion not available / 1 = Server supports recursion |
| **AD** | 1 | 0 = Not verified / 1 = DNSSEC authenticated data |
| **CD** | 1 | 0 = Checking enabled / 1 = Checking disabled (DNSSEC) |

---

## RCODE (Response Code) Values

| RCODE | Name | Meaning |
|-------|------|---------|
| 0 | NOERROR | Query completed successfully |
| 1 | FORMERR | Format error in the query |
| 2 | SERVFAIL | Server failed to complete the request |
| 3 | NXDOMAIN | Domain name does not exist |
| 4 | NOTIMP | Query type not implemented |
| 5 | REFUSED | Server refused to answer |

---

## Lab Exercise: Capture and Analyse

```bash
# Step 1: Start capture
sudo wireshark &
# OR: sudo tshark -i any -f "port 53" -w /tmp/dns_lab.pcap

# Step 2: Generate various DNS traffic
dig www.google.com                           # standard A query
dig MX gmail.com                             # MX record
dig +trace google.com                        # iterative trace
dig notexist.invalidtld9999.com              # NXDOMAIN test
dig axfr @nsztm1.digi.ninja zonetransfer.me  # zone transfer (TCP)
dig +tcp @8.8.8.8 google.com                 # forced TCP

# Step 3: In Wireshark, apply filters
# Filter 1: dns                     → see all DNS
# Filter 2: dns.flags.response==0   → only queries
# Filter 3: dns.flags.rcode==3      → only NXDOMAIN
# Filter 4: tcp.port==53            → zone transfer (TCP)
```

---

## What to Observe Per Filter

| What You Do | Wireshark Filter | What You See |
|-------------|-----------------|-------------|
| `dig google.com` | `dns` | UDP query + UDP response pair |
| `dig +tcp google.com` | `tcp.port == 53` | TCP 3-way handshake + DNS |
| `dig notexist.xyz` | `dns.flags.rcode == 3` | NXDOMAIN response |
| `dig axfr zonetransfer.me` | `tcp.port == 53` | Multiple DNS records over TCP |
| `dig +trace google.com` | `dns` | Multiple query/response pairs |
| `dig +dnssec google.com` | `dns` | OPT record with DO bit set |
