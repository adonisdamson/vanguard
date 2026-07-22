# Tema West — Bulk Operator Onboarding + Phone Login Plan

Status: **PLAN (not implemented)**. No commits/pushes until user approves.
Source data: `REGISTER.docx` — 512 people, 41 branches, Lashibi Ward.

---

## 1. Data reality (parsed from the register)

- **512 executives** across **41 branches**; 9-person committee per branch.
- Positions: CHAIRMAN 57 · SECRETARY 57 · ORGANISER 57 · TREASURER 56 ·
  COMMUNICATION 57 · YOUTH ORG 57 · WOMEN ORG 57 · OTHER MEMBER 114.
- **Fields available per person:** position, name, contact (phone), branch, ward.
- **Data-quality issues (must handle):**
  - 2 missing phones: ISSAKA ABU ALIYU (I C G C), ELIZABETH TSRAHINE (Pentecost Joy A).
  - 8 malformed phones: 9-digit (`024420252`, `024356947`, `055676953`, `05458084`,
    `050080192`, `054999784`) and O-for-0 typos (`O267918522`, `O243291015`).
  - 5 duplicate phone numbers (2 people share a number each; MUSTAPHA ISMAILA is a
    true double-entry).

## 2. Decisions locked (user, 2026-07-22)

1. **Role mapping** (safety-first):
   - Youth/Women/Other Member → `personnel`
   - Chairman/Secretary → `higher_authority`, labelled **"Coordinator"**
   - Organiser/Treasurer/Communication → **new `manager` role**, labelled
     **"Administrator"** (manage members/lookups/approve; NOT operator/role/password
     admin)
   - True `admin` (god-mode) = only existing named account(s); none of the 512 by
     default.
2. **These are OPERATORS** (they log in and use the app), not member records.
3. **Login by phone** (many have no email).
4. **Bad phone rows:** auto-fix obvious typos, import all valid+unique, hand back a
   short list of the ~15 problem rows to fix manually.

## 3. What already exists (reuse — don't rebuild)

- Auth = **Supabase** email/password (`signInWithPassword`). (Not Firebase.)
- **`must_change_password`** fully wired: schema → role provider → change-password
  screen that clears the flag. ⇒ "default password, force change on first login"
  already works.
- Admin can already create operators, change roles, reset passwords, suspend
  (Worker `/api/admin/operators/*` + operator_list_screen).
- CSV bulk-import screen exists (members) — proven pattern to adapt for operators.
- Profile screen exists — extend for full self-service edit.

## 4. Design

### 4a. Phone as login ID → synthetic email (recommended)
Map each normalized phone to an internal email `{phone}@temawest.local` and keep the
existing Supabase email/password stack. User types phone → app maps to synthetic
email → `signInWithPassword`. Phone also stored in `app_users.phone` for
display/search. Zero change to the auth engine; lowest risk.
(Alternative considered: native Supabase phone provider — cleaner but needs provider
config + more rework. Not chosen.)

### 4b. Default password
Shared default (e.g. `Ndc2025!`) + `must_change_password=true` on every imported
account → forced change on first login (already built). Accounts are low-value until
members are registered; forced change mitigates the shared-secret window.

### 4c. Phone normalization util
Trim spaces; `O/o → 0`; keep digits; validate `0\d{9}` (Ghana 10-digit). Reject/park
invalid; de-dupe.

## 5. Implementation phases

- **A. Schema & roles** — migration: add `manager` to `user_role` enum; add
  `position` (+ maybe `branch`) to `app_users`. RLS: `manager` gets member + lookup
  write like admin **minus** app_users/operator management + audit. Update
  `get_my_role()` consumers + member-update trigger to include `manager`. Worker:
  keep `/api/admin/operators/*` admin-only; add `manager` to exports/allowed reads.
- **B. Phone login** — login screen phone field → synthetic email map; phone
  normalization util; operator creation (Worker + Flutter) accepts phone → generates
  synthetic email + default password + `must_change_password`. Confirm change-pw flow.
- **C. Bulk import (512)** — one-time secure admin job: parse register → normalize →
  map position→role → `auth.admin.createUser({email:synthetic, password:default,
  email_confirm:true})` + `app_users` upsert (role, position, branch, name, phone,
  must_change_password=true). Skip+report the ~15 bad rows. Idempotent (safe re-run).
- **D. Admin panel** — operator management: search by phone; role picker now 4 roles;
  reset password; "add head". (Mostly exists; add phone search + manager option +
  friendly role labels.)
- **E. Self-service profile edit** — all users edit name/phone/photo after login
  (mobile + web). Extend profile_screen.
- **F. Web/PWA parity** — phone login + profile edit on web (PWA refactor already
  done, so mostly free).
- **G. Verify** — analyze, `flutter build web`, tests, one real login end-to-end.
  Then (with authorization) push.

## 6. Locked-decision docs to update on implement
CLAUDE.md: auth model (phone login via synthetic email), new `manager` role,
role labels. project memory.

## 7. Open follow-ups
- Exact default password string (user to pick).
- Which named account(s) remain true `admin`.
- Branch → does an operator's `branch` need to gate what members they see? (Currently
  personnel see only their own submissions; branch scoping optional.)
- The ~15 bad rows: correct now or after first import.
