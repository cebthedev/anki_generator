# Phase 3 Draft — Hosted Sync Service + Mobile Apps

Status: draft for discussion (2026-09-30)
Diagrams: [current v1.3.0](architecture/current-v1.3.0.html) · [Phase 3 proposed](architecture/phase3-proposed.html)

## 1. Goal

Seb generates decks with the gem (as today, free/local). The service adds one thing the gem cannot do: **decks that follow the user across devices** — generated server-side, visible seconds later in Android/iOS apps, studyable offline.

Non-goals for Phase 3:

- Replacing Anki. We export `.apkg` (Anki interop stays), but the apps render cards themselves — no Anki dependency on mobile.
- Multi-tenant SaaS scale. This is one developer + users measured in the hundreds, designed to run at near-zero cost.

## 2. Guiding constraints

1. **Cheap**: one small VPS (or free-tier container) + managed/free Postgres. No Kubernetes, no microservices.
2. **Reuse the gem**: the generation logic already exists and is tested (`AnkiGenerator::DeckBuilder`, `ClientFactory`, `ApkgWriter`). The service wraps it; it does not rewrite it.
3. **Offline first**: studying must work with zero connectivity; sync is a delta exchange, not a live requirement.
4. **Same quality bar**: Ruby 3.3, minitest, SimpleCov floor, RuboCop zero offenses, no AI-slop patterns (small classes, DI, explicit errors).

## 3. Architecture (see diagram)

```
Android / iOS / Web ──HTTPS+JSON──> Sync API (Ruby, thin) ──> PostgreSQL
                                      │  enqueue
                                      v
                                Solid Queue ──> Generation worker
                                      │            │ chat completions
                                      │            v
                                      │      OpenRouter / Ollama
                                      └──<── insert cards
Sync API ──> Object storage (.apkg exports, optional)
```

- **Sync API**: Sinatra (or Rails API-mode if it earns its keep). Auth via magic-link token (JWT). JSON endpoints only.
- **Generation worker**: a second process running the same codebase; consumes queue jobs, calls `ClientFactory.build(...)`, writes cards back to Postgres. Retries with backoff already exist in the client.
- **Web client**: the existing `serve` UI, hosted, with the API as its backend instead of in-process calls.
- **Object storage**: only for `.apkg` exports (S3-compatible or local disk on the VPS); the apps themselves read cards from Postgres via the API.

## 4. Data model (initial)

```
users          id, email, passwordless token fields, created_at
decks          id, user_id, name, source (manual|ai|import), updated_at
cards          id, deck_id, front, back, tags[], cloze text, ord position
review_state   card_id, ease, interval, due_at, reps, lapses   (per user)
gen_jobs       id, user_id, deck_id, prompt, provider, model, status, error
```

Cards are content; `review_state` is per-user scheduling (SM-2 to start — same algorithm Anki uses, ~30 lines, no gem needed).

## 5. Sync protocol (v1: dumb deltas)

Keep it boring; upgrade only when measurements say so.

- Client keeps a local SQLite mirror and a `last_synced_at` cursor.
- `GET /sync?since=t` → changed/ deleted cards, deck metadata, server time.
- `POST /sync` → client deltas (edits, review states) upserted by `(deck, client_uuid)`; conflicts: **last-write-wins** on content, review states merge by reps.
- Generation: `POST /generate` → `202 Accepted` + `job_id`; client polls `GET /jobs/:id` or receives a push token ping; finished job's cards appear in the next sync.

## 6. Cost estimate (hobbyist scale)

| Piece | Choice | ~Cost |
|---|---|---|
| API + worker + queue | 1 small VPS (Hetzner CX11-ish) or Fly.io free allowances | $0–5/mo |
| PostgreSQL | same VPS, or Neon/Supabase free tier | $0/mo |
| LLM | OpenRouter pay-per-use (~$0.1–1/mo at personal scale) or Ollama sidecar on the VPS | $0–1/mo |
| Object storage | local disk; S3 free tier if exported decks grow | $0/mo |
| **Total** | | **$0–6/mo** |

## 7. Milestones

1. **M1 — API skeleton**: auth (magic link), decks/cards CRUD, minitest + RuboCop from day one. Deploy to VPS with CI.
2. **M2 — Sync**: delta protocol, cursor, conflict rules; web client switched to the API.
3. **M3 — Generation service**: Solid Queue + worker reusing the gem; job status endpoint.
4. **M4 — Android app**: offline SQLite cache, review screen (SM-2), sync adapter. Kotlin + SQLDelight.
5. **M5 — iOS app**: Swift + GRDB, same protocol. (Or start with a shared KMP core if M4 made that tempting.)
6. **M6 — Polish**: `.apkg` export endpoint, push notifications, shareable read-only decks.

## 8. Open questions

- **Anki compatibility layer**: expose per-deck `.apkg` (cheap — reuse `ApkgWriter`) so users can also import into real Anki. Likely yes, M6.
- **Collaboration/shared decks**: out of scope until single-user sync is proven.
- **KMP vs separate mobile codebases**: decide at M4; protocol is plain JSON so both stay possible.
- **Billing**: none for personal use; if it ever trends, cap generation per user per day rather than building payments.
