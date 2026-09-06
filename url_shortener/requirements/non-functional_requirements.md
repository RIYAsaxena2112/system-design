**Non-Functional Requirements**

1.    **Low latency** — particularly on the redirect path, which is the system's hottest and most frequently hit operation.
2.    **High availability** — the system should tolerate individual node failures without user-facing downtime.
3.    **Horizontal scalability** — the system must scale out (add more machines), not just up (bigger machines), as traffic grows. No single component should be an unavoidable bottleneck at the design level.
4.    **Read-heavy traffic assumption** — working assumption of roughly a 100:1 read (redirect) to write (shorten) ratio, based on typical link-sharing behavior (one link created, then clicked by many recipients over its lifetime). This assumption directly drives caching and replication strategy in later design phases and will be sanity-checked during capacity estimation.
5.    **Consistency**
      * Write path: strong consistency required — needed to enforce per-user uniqueness and alias-collision checks correctly.
      * Read path: eventual consistency acceptable — a redirect served from briefly stale cache is an acceptable trade-off for speed.
6.    **Durability** — once a short link is successfully created, it must survive individual node/server failure (rules out in-memory-only storage).
7.    **Security**
       * User credentials must never be stored in plaintext (see Decision #5 — password hashing via bcrypt/argon2).
       * Only the owning user may mutate (delete) their own resources; authorization must be enforced on every mutating request.