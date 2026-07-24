# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

**Money Master** is a personal finance tracker (income/expense/transfer, person-to-person loans/ledger, budgets, investments, analytics). It exists as two clients against one Supabase backend:

- **Web app** (repo root) — Next.js 16 / React 19, deployed on Vercel, synced from a v0.app project.
- **Mobile app** (`mobile/`) — Flutter port of the same feature set, same Supabase project, currently ~97% feature-complete per [flutter_app_progress.txt](flutter_app_progress.txt).

Both clients talk directly to Supabase (Postgres + Auth) using row-level security as the authorization boundary — there is no separate backend API.

## Commands

### Web app (repo root)

```bash
npm run dev      # start Next.js dev server (turbopack, PWA disabled in dev)
npm run build    # production build (next build --webpack)
npm run start    # serve the production build
npm run lint     # next lint
```

There is no configured test runner for the web app.

### Mobile app (`mobile/`)

Flutter is installed at `C:\Users\bdCalling\development\flutter\bin\flutter.bat` (not on PATH by default). Run these from `mobile/`:

```powershell
.\tool\run_dev.ps1              # run in Chrome, reading Supabase keys from ../.env.local
.\tool\run_dev.ps1 -NoLaunch    # same, but as web-server on http://127.0.0.1:52710 without opening a browser
.\tool\build_android_debug.ps1  # build a debug APK with Supabase keys injected via --dart-define
flutter test                    # run the widget/unit test suite (test/)
flutter test test/some_file.dart  # run a single test file
flutter analyze                 # static analysis (must pass with no issues before calling work done)
dart format .                   # formatting
```

Supabase credentials are never baked into `AppConfig` directly — they're passed at build/run time via `--dart-define=SUPABASE_URL=...` / `--dart-define=SUPABASE_ANON_KEY=...`, sourced from the web app's `.env.local` (`NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY`). Windows Developer Mode must be enabled before `flutter pub get`/build will work with plugins.

### Database

SQL migrations live in `scripts/` and are run manually in the Supabase SQL editor, in order:

1. `001_create_tables.sql` — accounts, people, transactions, budgets + original anon-access RLS, later migrated to per-user `user_id` RLS in the same file.
2. `002_add_investments.sql` — investments table + `invest`/`invest_return` transaction types.
3. `003_performance_security.sql` — production hardening: revokes `anon` access entirely (authenticated-only RLS), adds composite indexes, and adds RPCs (`apply_money_mutation`, `money_master_dashboard_summary`, `money_master_transaction_page`) described below. **Must be run once before relying on server-side summaries/cursor paging** — both clients fall back to client-side computation if these RPCs aren't installed.

`scripts/unused_*.sql` are superseded/dead migrations — don't build on them.

## Architecture

### Data model (shared across both clients)

Everything is a `transaction` row with a `type` and up to two account/person/investment references — there's no separate ledger or balance table:

- `accounts` (cash/wallet/card) — balance is **never stored**, always derived by summing transactions.
- `people` — counterparties for loans.
- `investments` — named investment entities with `active`/`closed` status.
- `budgets` — per-month, per-category amount caps.
- `transactions.type` ∈ `income | expense | transfer | lend | borrow | repay | receive | invest | invest_return`, each interpreted by which of `from_account_id`/`to_account_id`/`person_id`/`investment_id` it populates (see `lib/types.ts` for the canonical enum + comments on what each loan/investment type means).

Account balance = `sum(amount where to_account_id = X) - sum(amount where from_account_id = X)`, computed client-side in [lib/balances.ts](lib/balances.ts) (web) and mirrored server-side in the `money_master_dashboard_summary` RPC / client-side in the Flutter repository. When changing balance logic, both implementations need to stay consistent.

RLS is the only authorization boundary (`auth.uid() = user_id` on every table). A `handle_new_user` trigger auto-creates the three default accounts (Cash/bKash/Card) on signup.

### `apply_money_mutation` RPC (idempotent writes)

Migration 003 adds `public.apply_money_mutation(mutation_id uuid, kind text, payload jsonb)`, a single `security invoker` function that performs every write (create/update/delete transaction, person, investment, budget, account adjustment) keyed by a client-generated `mutation_id`. A `money_mutation_receipts` table records `(user_id, mutation_id)` so retried mutations (e.g. from the Flutter offline queue) are no-ops instead of duplicate writes. If you add a new mutation kind, it needs a `case` branch here — the `kind` string is the contract between clients and this function.

### Web app (Next.js App Router)

- `components/dashboard.tsx` is the app's core client component — it owns almost all top-level state (accounts, transactions, people, investments, active tab/view mode, every modal's open/selected state) and fans out to feature components in `components/` (one file per modal/panel: `transaction-modal`, `transfer-modal`, `person-modal`, `investment-*-modal`, `budget-planner`, `ledger`, `spending-heatmap`, `financial-health-score`, `ai-insights`, etc). There is no global state manager — state lives in `Dashboard` and is threaded down as props.
- `components/ui/` is shadcn/ui (`components.json`: style `new-york`, base color `neutral`, icons from `lucide-react`). Regenerate/add primitives via the shadcn CLI rather than hand-rolling — check `components.json` aliases (`@/components`, `@/lib`, `@/hooks`) first.
- `lib/supabase/{client,server,middleware}.ts` — three separate Supabase client constructors for browser, server component, and middleware contexts respectively (standard `@supabase/ssr` split). `middleware.ts` + `lib/supabase/middleware.ts` gate `/` and `/analytics` behind auth and bounce authenticated users away from `/auth/*`.
- `lib/auth-context.tsx` wraps the app in a React context exposing `user`/`loading`/`signOut`, backed by `supabase.auth.onAuthStateChange`.
- `lib/transactions.ts` (`fetchAllTransactions`) paginates through Supabase in pages of 1000 to fetch the full transaction history — needed because balances are derived client-side from the complete transaction set, not a stored value. Any read path that needs correct balances must go through this rather than a single `select`.
- PWA: `next.config.mjs` wraps the config with `@ducanh2912/next-pwa` (disabled in dev, network-only for Supabase requests, network-first for navigations). Service worker lives at `public/sw.js`.
- `next.config.mjs` sets `typescript.ignoreBuildErrors: true` — `next build` will **not** catch type errors; run `tsc`/check `tsc_errors.log` separately if type safety matters for a change.

### Mobile app (Flutter, `mobile/`)

Layered by responsibility rather than by feature-first:

- `lib/data/` — the data layer against Supabase:
  - `money_repository.dart` — main repository; defines `AccountBalance`, `LedgerEntry`, cursor-paged `TransactionPage`/`TransactionCursor`, and `DashboardServerSummary` (mirrors the `money_master_dashboard_summary` RPC shape), with client-side fallback when server RPCs aren't installed.
  - `cached_money_data_source.dart` — cache-first wrapper: serves cached dashboard snapshots immediately, revalidates in the background, coordinates concurrent refreshes into one request, and invalidates on any CRUD mutation.
  - `offline_mutation_queue.dart` — persists mutations for retry when offline, keyed by the same `mutation_id` pattern the `apply_money_mutation` RPC expects for idempotency.
  - `secure_cache_store.dart` — encrypts cached dashboard/queue data at rest with AES-256-GCM, key held in platform secure storage (Android backup is disabled for this reason — see `mobile/README.md`).
- `lib/models/money_models.dart` — Dart models mirroring the Supabase schema/`lib/types.ts` on the web side. Keep these two in sync when the schema changes.
- `lib/features/<feature>/` — one folder per screen/flow (`accounts`, `auth`, `budget`, `dashboard`, `investments`, `people`, `transactions`, `analytics`, `settings`), each typically a single `*_sheet.dart`/`*_screen.dart`. Forms all use the shared full-page form shell in `lib/shared/widgets/app_form_page.dart` (fixed save/cancel action bar, scrollable content, drag-to-dismiss keyboard) rather than draggable modal sheets — this was a deliberate migration away from bottom sheets, see `flutter_app_progress.txt` items 18–26.
- `lib/shared/widgets/app_dialogs.dart` / `app_state_widgets.dart` — shared destructive-confirmation dialog and shared empty/error/skeleton-loading widgets, used everywhere instead of ad hoc equivalents.
- `lib/core/date_times.dart` — timezone-safe timestamp handling: all writes to Supabase go through this to serialize as UTC ISO-8601 with a `Z` suffix, and reads convert back to local time before display. This exists because of a real bug (late-night transactions shifting to the wrong day) — don't bypass it with raw `DateTime.toIso8601String()` on transaction timestamps.
- State management: `flutter_riverpod`; navigation: `go_router`.
- Tests live in `mobile/test/`, one file per feature/concern (e.g. `transaction_entry_sheet_test.dart`, `dashboard_snapshot_test.dart` for pure finance-calculation logic, `production_hardening_test.dart`). Widget tests commonly assert layout at 320×568 (small phone) and 1440×900 (desktop) — match this convention for new UI tests.

## Conventions

- No automated test suite exists for the web app; the Flutter app's bar is `flutter analyze` clean + `flutter test` passing + `dart format` applied before considering a change done (this is the standard this codebase has been held to throughout `flutter_app_progress.txt`).
- Frontend UI work should avoid generic AI-generated aesthetics per `.agents/skills/frontend-design/SKILL.md` (no default Inter/Roboto, no purple-gradient-on-white, commit to a distinctive visual direction) — applies to new web UI.
- When changing money-affecting logic (balance calculation, transaction types, mutation kinds), update both the web (`lib/balances.ts`, `lib/types.ts`) and mobile (`lib/data/money_repository.dart`, `lib/models/money_models.dart`) implementations, and the `apply_money_mutation`/summary RPCs in `scripts/003_performance_security.sql` if server-side logic is affected.
