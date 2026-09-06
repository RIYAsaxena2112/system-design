# Capacity Estimation

**Baseline assumption:** 1 billion short URLs created over 10 years. Read:write ratio ~100:1 (see Non-Functional Requirements / Decisions Log #6).

## Traffic (QPS)

| | Average | Peak (x2) |
|---|---|---|
| Write (`shorten`) | 1B / (10 × 365 × 86400 sec) ≈ **3.2 QPS** | ~6-7 QPS |
| Read (`redirect`) | 3.2 × 100 ≈ **317 QPS** | ~630-650 QPS |

Peak multiplier of 2x applied per the availability/low-latency NFRs — infrastructure is sized against peak, not average, since average-case provisioning would mean degraded performance during real-world traffic spikes.

## Storage

**Link table:** 1B rows × ~500 bytes/row (short code, long URL, user_id, timestamps, expiry) ≈ **500 GB** over 10 years.

**Click analytics:** total click events over 10 years = total writes × read:write ratio = 1B × 100 = 100 billion events. At ~100 bytes/event (short_code reference, timestamp, referrer/device hash) ≈ **~10 TB** over 10 years.

**Key finding:** raw click-analytics storage is ~20x larger than the core link table. This will directly inform HLD:
- The link table and analytics data should very likely be stored in separate systems with different guarantees (link table: small, hot, strongly consistent on write; analytics: large, append-only, more relaxed consistency).
- Whether to store every raw click event vs. aggregated counts (e.g. per-link click totals, daily buckets) is an open question to resolve at HLD/LLD — it materially changes this number.

## Bandwidth

- **Write path:** ~1 KB request (long URL + headers) + ~0.5 KB response (short code) per call. At peak write QPS (~7): **~10 KB/sec** — negligible.
- **Read path:** ~0.5 KB request + ~0.3-0.5 KB redirect response (no body) per call. At peak read QPS (~650): **~300-400 KB/sec** — negligible.

**Conclusion:** this system is never bandwidth-bound. The real constraints are QPS handling (high volume of small, fast requests) and storage growth — particularly from analytics, not the core link data.
