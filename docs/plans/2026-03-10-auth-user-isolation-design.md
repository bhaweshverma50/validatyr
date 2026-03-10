# Auth & Per-User Data Isolation Design

**Date:** 2026-03-10
**Status:** Approved

## Decision

Supabase Auth with RLS-enforced per-user data isolation. Email+password and Google/Apple social login. Auth wall (login required before any access).

## Platforms

iOS, Android, macOS desktop.

## Database Changes

Wipe all existing data. Add `user_id UUID REFERENCES auth.users(id) NOT NULL ON DELETE CASCADE` to all tables:

- `validations`
- `validation_jobs`
- `research_topics`
- `research_jobs`
- `research_reports`
- `notifications`
- `push_tokens`

RLS policies on every table:
```sql
CREATE POLICY "Users can CRUD own data" ON <table>
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

No new tables needed. Profile data (name, avatar) lives in `auth.users.raw_user_meta_data` from social login.

## Backend

### Auth Middleware

New file `backend/services/auth.py`:
- FastAPI dependency extracting/verifying Supabase JWT from `Authorization: Bearer <token>`
- Uses `SUPABASE_JWT_SECRET` env var
- Returns `user_id` (UUID) or raises 401

### Route Changes

All routes in `routes.py` and `research_routes.py` get auth dependency. `user_id` passed to all service/DB functions.

### Data Layer

- `db.py` — all functions take `user_id`, include in INSERT/SELECT
- `research_db.py` — all CRUD functions take `user_id`
- Supabase client uses user's JWT so RLS applies server-side

### Cron Jobs

Cron endpoint (`POST /api/v1/research/cron-trigger`) continues using service role + `X-Cron-Secret`. Topics already carry `user_id` so results are isolated.

### New Env Var

- `SUPABASE_JWT_SECRET`

## Frontend

### New Screens

- `LoginScreen` — email+password form, Google/Apple social buttons, link to sign-up
- `SignUpScreen` — registration form with social buttons
- `ProfileScreen` — name/email/avatar, logout button, delete account button

### Auth State

- Riverpod `authStateProvider` listening to `Supabase.auth.onAuthStateChange`
- App root: authenticated -> HomeScreen, unauthenticated -> LoginScreen
- Sessions persisted by `supabase_flutter` SDK

### API Calls

All backend requests include `Authorization: Bearer <access_token>`. On 401, redirect to LoginScreen.

### Social Login

- Google: `google_sign_in` package -> `Supabase.auth.signInWithIdToken()`
- Apple: `sign_in_with_apple` package -> `Supabase.auth.signInWithApple()`
- Both work on iOS, Android, macOS

### UI Style

Auth screens use existing retro/neo-brutalist theme (RetroCard, RetroButton, bold borders, pastel colors).

## Per-User Isolation

Double-layered: app-level `user_id` filtering + DB-level RLS.

Account deletion cascades to all user data via `ON DELETE CASCADE` foreign key.

## Setup Steps (manual, outside codebase)

1. **Run migration:** Execute `backend/migrations/002_add_auth_and_user_isolation.sql` in Supabase Dashboard SQL Editor
2. **Supabase JWT Secret:** Dashboard > Settings > API > Copy JWT Secret > add to backend `.env` as `SUPABASE_JWT_SECRET`
3. **Supabase Auth Providers:** Dashboard > Authentication > Providers:
   - Email (enabled by default)
   - Google: paste Web Client ID + Client Secret from Google Cloud Console
   - Apple: paste Service ID, Team ID, Key ID, Private Key from Apple Developer
4. **Google Cloud Console:** Create OAuth 2.0 client IDs for iOS, Android, and macOS platforms
5. **Apple Developer:**
   - Register App ID with "Sign in with Apple" capability
   - Create a Service ID for Supabase callback
6. **iOS:** Add Google Sign-In reversed client ID URL scheme to `ios/Runner/Info.plist`
7. **macOS:** Add "Sign in with Apple" capability in Xcode + entitlements file
8. **Android:** Add SHA-1 fingerprint to Firebase/Google Cloud project
9. **Flutter build args:** Pass Google client IDs via `--dart-define`:
   ```
   flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxx --dart-define=GOOGLE_IOS_CLIENT_ID=yyy
   ```
