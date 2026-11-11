# PubMagic (publishing videos to YouTube Shorts)

PubMagic publishes a vertical video to a connected **YouTube channel** through the official YouTube Data API. It is a **restricted feature**: only users TimeMagic has explicitly allowed can see or call it. For everyone else every PubMagic endpoint answers `404` and the MCP tools are not listed. A `404` on the very first PubMagic call therefore means "this account does not have PubMagic" - tell the user, do not retry, do not look for a workaround.

Use it when the user asks to upload/publish/schedule a video to YouTube Shorts through TimeMagic. Everything is for the *user's own* channel.

## What differs from the rest of the API

- Resources use plain **integer `id`**, not `uuid`.
- Responses are wrapped: `{"accounts": [...]}`, `{"media_assets": [...]}`, `{"publications": [...]}`, `{"publication": {...}}`, `{"media_asset": {...}}`. Errors are `{"errors": [...]}` (a list of strings).
- Write bodies are **flat** (no `{"publication": {...}}` root): `{"social_account_id": 1, "title": "..."}`. `tags` is a JSON **array**.
- The usual rules still apply: Bearer token, `GET` needs an active subscription, **5 requests/minute** (space out status polling, do not hot-loop).

## Hard rules

1. **Never publish without the user's explicit approval** of this exact video, channel, title and visibility. Show them the summary first (see "Flow"). Approval for one video or one channel is not approval for another.
2. **Never answer the declarations yourself.** `made_for_kids` and `contains_synthetic_media` must be decided by the user; ask both. Do not default them.
3. **Visibility defaults to `private`.** Use `unlisted` or `public` only when the user asks for it.
4. **Connecting a channel is browser-only** (`/pubmagic` -> `Connect YouTube`). Agents cannot connect or reconnect it, and must never ask for Google passwords, client secrets or refresh tokens. If there is no connected account (`GET /api/pubmagic/accounts` is empty or `status` is not `connected`), send the user to `/pubmagic`.
5. **Credentials are never returned** by the API; do not try to read them.
6. **Do not retry an upload whose outcome is unknown.** If a publication is `requires_attention`, report it and let the user decide; look at YouTube Studio before any retry.
7. Never upload footage the user did not choose, and never publish "just to test".

## Flow

1. **Accounts** - `GET /api/pubmagic/accounts` -> `{"accounts": [{"id", "provider", "channel_id", "name", "status", "last_error"}]}`. Use an account whose `status` is `connected`.
2. **Upload the video** (creates a media asset; nothing goes to YouTube):

   ```bash
   curl -s -H "Authorization: Bearer $TIMEMAGIC_API_TOKEN" \
     -F "video=@short.mp4;type=video/mp4" https://time-app.purple-magic.com/api/pubmagic/media_assets
   ```

   Response: `{"media_asset": {"id", "filename", "width", "height", "duration", "byte_size", "validation_status", "messages": [{"level", "code", "text"}]}}`. `messages` are Shorts **warnings** (over 180 s, not vertical 1080x1920, not H.264/AAC, no audio track); they never block and the file is never modified. Only an unreadable file, no video stream, or more than 2 GB is an error. Over MCP use `create_pubmagic_media_asset` (base64, **max 25 MB**); for larger files use the multipart REST call.
3. **Create a draft** - `POST /api/pubmagic/publications` (still nothing sent to YouTube):

   ```json
   {"social_account_id": 1, "media_asset_id": 1, "title": "Short title (max 100)", "description": "What the video shows.", "tags": ["tag1", "tag2"], "privacy": "private", "made_for_kids": false, "contains_synthetic_media": false}
   ```

   Optional: `notify_subscribers`, `scheduled_at` (ISO 8601). `made_for_kids` and `contains_synthetic_media` are required answers from the user. Returns `{"publication": {"id", "status": "draft", ...}}`. A draft or failed publication can be edited with `PATCH /api/pubmagic/publications/:id` (same fields). After it is queued or uploaded it can no longer be edited through the API - changes then happen in YouTube Studio.
4. **Publishing** - `POST /api/pubmagic/publications/:id/publish`.
   - Without `"confirm": true` it is a **preview**: it returns what would be sent, `blockers` and `duplicates`, and sends nothing. Do this first and show it to the user.
   - After the user explicitly approves, send `{"confirm": true}` (a JSON boolean). If the same video is already on that channel the call is refused until you also send `"allow_duplicate": true` - only when the user really wants a repost.
   - Blockers (same as the web UI): unanswered kids/synthetic declarations, no connected account, a `scheduled_at` in the past, an invalid video.
5. **Follow it** - `GET /api/pubmagic/publications/:id` (or `GET /api/pubmagic/publications?status=`). Poll sparingly (rate limit); statuses move on their own.

## Statuses

`draft` -> `queued` -> `uploading` -> `uploaded` -> `processing` -> `published` or `scheduled`; exits are `failed` and `requires_attention`. `uploaded` means YouTube accepted the bytes, **not** that the video is live: a background job checks YouTube about every 5 minutes, so `published` can take several minutes. Treat the video as published only when the status is `published` (or `scheduled` for a future `scheduled_at`), and give the user `shorts_url` / `youtube_url` from the response so they can verify it in YouTube Studio.

`error_code` / `error_message` explain failures (quota is retried automatically hours later; rejected metadata is `failed`; a revoked Google authorization shows the account as `requires_reauth` - the user must press `Reconnect` at `/pubmagic`).

## Scheduling

Set `scheduled_at` (ISO 8601, in the future). The video is uploaded immediately as **private** with YouTube's own `publishAt`, and YouTube makes it public at that time - TimeMagic's servers need not be running then. Visibility is forced to `private` while a schedule is set. Cancelling or changing the time after upload is done in YouTube Studio.

## Limits to tell the user about

- Video is never re-encoded or cropped; Shorts rules only produce warnings.
- While TimeMagic's Google OAuth app is in Testing mode, the channel connection expires after 7 days and needs `Reconnect`.
- Newly created YouTube API projects can be forced to keep uploads private until they pass Google's audit.
- Only YouTube is supported (no Instagram Reels or TikTok).

## MCP tools

Same operations, same rules (restricted: visible only to allowed users): `list_pubmagic_accounts`, `list_pubmagic_media_assets`, `create_pubmagic_media_asset`, `list_pubmagic_publications`, `get_pubmagic_publication`, `create_pubmagic_publication`, `update_pubmagic_publication`, `request_pubmagic_publication` (`confirm`, `allow_duplicate`). See `references/tool_usage.md`.
