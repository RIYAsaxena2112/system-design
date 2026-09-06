**Functional Requirements**

**Core Operations**
1.  Shorten a URL shorten(long_url, user_id, custom_alias?, expiration?) -> short_url
    *    Idempotent per user: if the same authenticated user  submits the same long_url again, the same short code is returned.
    *    Different users shortening the same long_url each receive their own independent short code (uniqueness is scoped to (user_id, long_url), not long_url alone).

2.  Redirect redirect(short_code) -> HTTP redirect to original long URL
    *    This is the hottest path in the system (see NFRs — read-heavy traffic assumption).

3.  Custom alias
    *    Users may request a custom alias instead of an auto-generated code.
    *    If the requested alias is already taken, the system auto-generates a suffixed variant (e.g. myalias-x7f2) rather than rejecting the request outright.

4.  Expiration
    *    Every short link may have an optional expiration timestamp.
    *    After expiry, redirect() no longer resolves the link. (Exact behavior — 404 vs. a dedicated "expired" response — is an API design decision, not resolved here.)

5.  Deletion
    *    The owning user may delete their own link before its expiration.
    *    Deletion requires authentication and ownership verification.

6.  Click analytics
    *    Each redirect is logged (click count; additional fields such as timestamp/referrer to be defined at LLD).
    *    Constraint: analytics logging must NOT add synchronous write latency to the redirect path. The mechanism (async write, batching, event queue, etc.) is resolved at HLD.

7.  User accounts
    *    Users can sign up and log in.
    *    Ownership of a short link is tied to the authenticated user who created it.
    *    See Decision #4 (ownership model) and Decision #5 (auth mechanism) in the decisions log.

**Explicitly Out of Scope for v1**

    -    Editing an existing short URL's destination
    -    Password-protected or one-time-use links
    -    Bulk/batch shortening API