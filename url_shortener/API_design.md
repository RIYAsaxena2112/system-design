# API Design

Base path: `/api/v1` (redirect endpoint is the exception — see below).

---

## 1. Shorten a URL

`POST /api/v1/shorten`

**Headers:** `Authorization: Bearer <access_token>`

**Request body:**
```json
{
  "long_url": "https://example.com",
  "alias": "custom-promo",
  "expires_at": "2027-09-08T21:00:00Z"
}
```
`alias` and `expires_at` are optional.

**Responses:**

| Code | Meaning |
|---|---|
| `201 Created` | New short link created. |
| `200 OK` | This user already shortened this exact `long_url` (idempotent hit) — existing link returned. |
| `401 Unauthorized` | `{"error": "Missing, invalid, or expired access token"}` |
| `422 Unprocessable Entity` | `{"error": "Malformed long_url or invalid expiration date"}` |

**Success payload (200 or 201):**
```json
{
  "short_code": "custom-promo-x7f2",
  "requested_alias": "custom-promo",
  "short_url": "https://sho.rt/custom-promo-x7f2",
  "long_url": "https://example.com",
  "created_at": "2026-09-08T22:15:00Z",
  "expires_at": "2027-09-08T21:00:00Z"
}
```
`requested_alias` is included whenever it differs from `short_code`, so the client can detect the auto-suffix without diffing strings (Decision #2).

---

## 2. Redirect

`GET /{short_code}`

Deliberately at the root, not under `/api/v1` — the whole value of a short link is that it stays short.

**Headers:** none required. **Body:** forbidden (GET).

**Responses:**

| Code | Meaning |
|---|---|
| `302 Found` | Valid, active link — `Location` header set to the long URL. Deliberately temporary (not `301`) so the browser never caches the redirect locally — see Decisions Log for why this matters for analytics and expiration/deletion. |
| `410 Gone` | Link existed but has expired or was deleted. |
| `404 Not Found` | `short_code` was never created. |

---

## 3. Delete a link

`DELETE /api/v1/shorten/{short_code}`

**Headers:** `Authorization: Bearer <access_token>`. **Body:** forbidden.

**Responses:**

| Code | Meaning |
|---|---|
| `204 No Content` | Deleted successfully. |
| `401 Unauthorized` | Missing/invalid/expired token. |
| `403 Forbidden` | Valid token, but this user doesn't own this link. |
| `404 Not Found` | `short_code` doesn't exist. |

---

## 4. List own links

`GET /api/v1/links`

**Headers:** `Authorization: Bearer <access_token>`

**Responses:**

| Code | Meaning |
|---|---|
| `200 OK` | Returns the authenticated user's own links (paginated — pagination scheme to be finalized at LLD). |
| `401 Unauthorized` | Missing/invalid/expired token. |

---

## 5. Signup

`POST /api/v1/auth/signup`

**Request body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}
```

**Responses:**

| Code | Meaning |
|---|---|
| `201 Created` | Account created. |
| `409 Conflict` | `{"error": "Email already registered"}` |
| `422 Unprocessable Entity` | `{"error": "Invalid email format or password does not meet strength requirements"}` |

**Success payload (201):**
```json
{
  "user": {
    "id": "usr_9j2x4k8m",
    "email": "user@example.com",
    "created_at": "2026-09-08T23:10:00Z"
  },
  "token_type": "Bearer",
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 3600
}
```
Also sets `refresh_token` as an HttpOnly, Secure, `SameSite=Strict` cookie (Decision #7) — never returned in the JSON body.

---

## 6. Login

`POST /api/v1/auth/login`

**Request body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}
```

**Responses:**

| Code | Meaning |
|---|---|
| `200 OK` | Same payload shape as signup (minus `created_at`), same refresh cookie behavior. |
| `401 Unauthorized` | `{"error": "Invalid email or password"}` — deliberately generic, doesn't reveal which field was wrong. |

*(No `423 Locked` — see Decision #8. Brute-force protection deferred to v2.)*

---

## 7. Refresh access token

`POST /api/v1/auth/refresh`

**Headers:** none — refresh token is read from the HttpOnly cookie, not a header or body.

**Responses:**

| Code | Meaning |
|---|---|
| `200 OK` | Returns a new `access_token` (same shape as the `access_token`/`token_type`/`expires_in` fields above). |
| `401 Unauthorized` | Refresh token missing, invalid, or revoked — client must re-login. |

---

## 8. Logout

`POST /api/v1/auth/logout`

**Headers:** none required beyond the refresh cookie.

**Responses:**

| Code | Meaning |
|---|---|
| `204 No Content` | Refresh token revoked server-side; cookie cleared. |

This is what makes the "revocable" part of Decision #5's refresh token actually mean something — without it, a stored refresh token could never be invalidated before its natural expiry.