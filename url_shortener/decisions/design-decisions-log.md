**Design Decisions Log**

**Format per entry**: Decision | Options Considered | Choice | Reasoning | Trade-off Accepted

1. **Idempotency scope**
* **Options considered**: Global idempotency (one long_url -> one short URL, system-wide) vs. per-user idempotency ((user_id, long_url) unique).

* **Choice**: Per-user idempotency.
* **Reasoning**: With full user accounts and link ownership, a globally shared short code would mean the first user to shorten a URL "owns" it, and every later user gets a code they don't own and can't manage — poor UX once ownership exists.
* **Trade-off accepted**: Unique constraint is (user_id, long_url) rather than long_url alone — a larger index, and the same destination URL can legitimately appear multiple times in storage under different owners.

2. **Alias collision handling**
* **Options considered**: Reject the request with an error vs. auto-generate a suffixed variant.
* **Choice**: Auto-suffix (e.g. myalias-x7f2).
* **Reasoning**: Prioritizes "the request never hard-fails" over "the user gets the exact alias they typed."

* **Trade-off accepted**: User may not receive their exact desired alias. UI/API should surface this clearly (resolved at API design stage).

3. **Consistency model**
* **Options considered**: Strong consistency everywhere / eventual consistency everywhere / split by read vs. write path.
* **Choice**: Strong consistency on writes, eventual consistency on reads.
* **Reasoning**: Uniqueness and alias-collision checks require every write to see the latest state. Redirects are read-heavy (~100:1) and can tolerate brief staleness in exchange for speed.

* **Trade-off accepted**: A link created within the last cache-refresh window may briefly miss cache or resolve inconsistently on first read, depending on the caching strategy chosen at HLD.

4. **Ownership / deletion model**
* **Options considered**: (a) full user accounts, (b) anonymous creation + secret delete-token (Pastebin-style), (c) no protection (anyone with the short code can delete).
* **Choice**: (a) Full user accounts.
* **Reasoning**: Enables persistent ownership across sessions and devices, and is the most realistic model for a product with accounts.

* **Trade-off accepted**: Adds an entire auth subsystem (signup, login, credential storage, token/session handling) that is tangential to the core distributed-systems problem this project is meant to demonstrate. Mitigation: auth will be designed as a clearly separable module/service boundary, not entangled with core shortening/redirect logic.

5. **Authentication mechanism**
* **Options considered**: Stateless JWT (short-lived access token + revocable refresh token) vs. server-side sessions backed by a shared store (e.g. Redis).
* **Choice**: JWT-based (access + refresh tokens). Recommended at requirements stage; to be finalized in detail at HLD.

* **Reasoning**: Access tokens are verified via signature only — no DB/cache lookup required — which preserves true statelessness across horizontally scaled app servers (no sticky sessions needed). Also avoids adding auth traffic to the same Redis instance being relied on for redirect-path caching, keeping the two concerns decoupled.
* **Trade-off accepted**: Revocation is harder than server-side sessions — a stolen access token remains valid until it expires. Mitigated by keeping access token lifetime short (~15 min) and storing refresh tokens server-side so they can be revoked.
Locked-in regardless of mechanism: passwords hashed with bcrypt/argon2 — plaintext storage is not an option.

6. **Read:write traffic ratio assumption**
* **Options considered**: This is a working assumption, not a binary fork.
* **Choice**: ~100:1 (reads:writes).

* **Reasoning**: A single shortened link is typically created once but clicked many times across its distribution (chat, social, email). 100:1 is a standard anchor for this class of system.
* **Trade-off accepted**: None yet — to be validated against real numbers during capacity estimation.

7. **Refresh token storage**
*    **Options considered**: Return refresh token in the JSON response body (alongside access token) vs. set it as an HttpOnly, Secure cookie.
*    **Choice**: HttpOnly, Secure, SameSite=Strict cookie, scoped to the auth/refresh path.

*    **Reasoning**: The access token must be readable by client code (attached to Authorization headers on every request), but the refresh token only ever needs to reach one endpoint. Excluding it from anything JavaScript-accessible meaningfully reduces exposure to XSS-based token theft.
*    **Trade-off accepted**: Cookie-based tokens introduce CSRF considerations, mitigated by SameSite=Strict and restricting the cookie's path.

8. **Brute-force login protection**
*    **Options considered**: Implement account lockout (423 Locked) with failed-attempt tracking vs. defer to v2.
*    **Choice**: Deferred out of scope for v1 — all authentication failures return uniform 401.

*    **Reasoning**: Lockout requires new schema (failed-attempt counters, lockout timestamps/policy) not yet designed. A status code implying a mechanism that doesn't exist would be misleading.
*    **Trade-off accepted**: No brute-force protection at the API layer in v1. Acceptable for a portfolio project; flagged as a known gap for any production extension.

9. **List user's links (gap discovered during API design)**
*    **Options considered**: Add GET /api/v1/links vs. leave it undiscoverable in v1.
*    **Choice**: Added GET /api/v1/links — paginated, returns only the authenticated user's own links.

*    **Reasoning**: Without it, deletion (already a committed feature) is unusable in practice — a user can't delete a link whose short_code they don't already know from memory.
*    **Trade-off accepted**: None significant. Retroactively added to Functional Requirements as FR #8.

10. **Token refresh & logout endpoints**
*    **Options considered**: Implement POST /auth/refresh and POST /auth/logout vs. omit.
*    **Choice**: Implement both.

*    **Reasoning**: Decision #5 chose short-lived access tokens specifically so they could be renewed via a refresh token, and chose server-side-stored refresh tokens specifically so they could be revoked. Neither mechanism is usable without these endpoints.
*    **Trade-off accepted**: None significant — both are completions of already-made decisions, not new scope.