# Authentication

## Header

```
Authorization: Bearer <api_token>
```

A legacy HTTP Token auth scheme is also accepted server-side, but `Bearer` is the documented and recommended form.

## Getting a token

1. Log into TimeMagic.
2. Go to `https://time-app.purple-magic.com/docs/api`.
3. The "API Token" section shows the current token and a "Regenerate token" button.
4. Store it as the `TIMEMAGIC_API_TOKEN` environment variable. Regenerating invalidates the old token immediately.

Tokens are plain per-user secrets (32 chars), not JWTs — there's no expiry/refresh flow. Treat a 401 as "token missing, wrong, or regenerated," not "expired."

## Access rules

- **GET requests require an active subscription** on the token owner's account. Without one: `402 Payment Required`, `{"info": "Subscription required for GET requests."}`.
- **POST/PUT/PATCH/DELETE do not require a subscription.**
- This means a free account can still create/update/delete via the API but can't read back the result through the API — surface this to the user plainly if they hit a 402 on a GET.

## Rate limits

- **5 requests per minute per user**, counted server-side (not per-IP).
- No `X-RateLimit-*` or `Retry-After` headers are returned.
- Exceeding it: `429 Too Many Requests`, `{"info": "Rate limit exceeded. Try again later."}`.
- When batching calls (e.g. listing tasks across many projects), pace requests — don't fire more than ~5/minute per token.
