# DineCircle Phase 3 Plan — Complete Core Features, PostgreSQL Integration & Functional Testing

**Phase:** 3
**Created:** November 3, 2026
**Precondition:** Phase 2 (backend / database / security verification) substantially complete
**Estimated Duration:** 15–20 working days
**Roles:** Senior Flutter Engineer · Express.js Backend Architect · PostgreSQL Engineer · Application Security Specialist · QA Lead

---

## 1. Mission

Complete, connect, debug, and test all **essential** Partner App functionality end-to-end through the **existing** shared stack.

| Layer | Component |
|---|---|
| Mobile | DineCircle Customer App (Flutter) |
| Mobile | DineCircle Partner App (Flutter) |
| Backend | Existing Express.js REST API + Socket.IO |
| Data | Existing shared **PostgreSQL** database (~79 tables, verify actual) |

> **Hard constraint: the project uses PostgreSQL, NOT Supabase.** No Supabase, no Firebase Database, no second backend, no second database, no duplicate tables or endpoints.

**Workflow:** Audit existing → Identify gaps → Implement → Integrate APIs → Test → Fix → Verify.

---

## 2. Non-Negotiable Rules

1. Inspect the existing project before modifying anything.
2. Review `AUDIT_REPORT_PHASE1.md` and the Phase 2 implementation results first.
3. Preserve the existing Flutter architecture: Riverpod providers, repositories, navigation table, theme.
4. Reuse the existing Express backend and its middleware.
5. Reuse existing PostgreSQL tables and relationships.
6. No duplicate tables, endpoints, or services.
7. Do not rebuild screens or features that already work.
8. Use real records through authenticated APIs — no mocks in production code.
9. Missing functionality is implemented on **both** frontend and backend together.
10. Preserve Customer App compatibility; never break an existing consumer.
11. Server-side authorization for **every** partner operation.
12. Parameterized SQL only, via the existing connection pool.
13. No destructive database changes; migrations are versioned and reviewed.
14. No unnecessary redesign.
15. Every screen gets loading / empty / error / success / retry states.
16. Automated tests for each completed feature.
17. Nothing is marked complete without verification evidence.

**Known existing constraints to respect (verified in Phase 1 / prior sessions):**
- Backend routes live in `DineCircle-master/server/src/routes/` split by domain: `partner.ts`, `partner_ops.ts`, `partner_venues.ts`, `partner_menu.ts`, `partner_tables.ts`; contract doc is `server/docs/PARTNER_API.md`.
- Response envelope is `{ data: { <resource>: ... }, meta }` for most reads; a few diner-facing reads return bare objects (`GET /reviews`, `POST /feedback`) — the `ApiEnvelope` parser already passes those through.
- Permissions use `requireVenueRole` with ladder `staff < manager < owner`; `super_admin` bypasses venue roles. Client mirrors this with `Capability` + `RoleGate`.
- Tab routes use query-bearing names (`/business?tab=analytics`) requiring `onGenerateRoute` resolution; screens read tabs via `routeQuery(context)`. Do not drop query strings.
- `DataGrid` sizes from aspect ratio — computed height must be treated as a floor or `RenderFlex` overflow occurs at narrow widths / large text scale.
- Known backend gaps rendered as disabled UI: review reply, deal redemption wiring, venue↔host chat, media upload, push notifications, per-date closures, per-booking dietary requirements, payout bank editing, server-side notification prefs.
- Dev runtime: Postgres on `127.0.0.1:5433` (user-space cluster, not persistent across reboot), API on `http://localhost:4000`, Flutter SDK at `~/flutter`, `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`.

---

## 3. Stage 0 — Architecture Verification (before Batch 1)

Inspect and document, do not assume:

- [ ] Partner App screens, navigation table, `onGenerateRoute`, and `routeQuery` usage.
- [ ] Riverpod providers (`app_providers.dart`, `venue_scope_provider.dart`) and session/venue-scope controllers.
- [ ] Models and repositories (`venue`, `menu`, `business`, `operations`, `experience`).
- [ ] Express routes, controllers, services, middleware, validators.
- [ ] PostgreSQL connection config and pool settings.
- [ ] Actual tables, constraints, FKs, indexes (`\dt`, `\d+ <table>`).
- [ ] Auth/session flow and token lifecycle.
- [ ] Restaurant ownership + staff membership verification path.
- [ ] Customer App consumers of the same endpoints.
- [ ] Socket.IO events and current listeners.
- [ ] Existing test suites (`test/`, server tests).

**Output:** a short architecture snapshot appended to the Phase 3 working log, plus a confirmed list of endpoints per batch.

**Run check:**
```bash
pg_isready -h 127.0.0.1 -p 5433
curl -s http://localhost:4000/api/health
cd ~/Downloads/Projects/DineCircle/DineCircle-master/server && npm start
```

---

## 4. Batch 1 — Restaurant & Café Management (P0)

**Goal:** restaurant management fully functional on real PostgreSQL data.

### Features
- [ ] Restaurant registration + partner onboarding
- [ ] Profile create/edit: name, description, contact, cuisines
- [ ] Logo, cover image, gallery (uses Batch 5 upload)
- [ ] Address + map coordinates
- [ ] Opening/closing hours, temporary closure
- [ ] Verification request + status
- [ ] Multiple branches (where schema supports)
- [ ] Staff management
- [ ] Publishing/visibility status

### Backend to verify & repair
- [ ] Ownership relationship enforced on every read and write
- [ ] Partners see only authorized restaurants
- [ ] Updates persist; server-side validation
- [ ] Restaurant id validated and never trusted from the body
- [ ] Public vs private field separation in responses
- [ ] DB errors surfaced as safe API errors
- [ ] Customer App endpoints unchanged

### Touch points
`lib/repositories/venue_repository.dart` · `lib/models/venue.dart` · `lib/screens/` restaurant screens · `server/src/routes/partner_venues.ts` · `restaurants`, `restaurant_branches`, `restaurant_staff`, `restaurant_hours`

### Done when
Partner registers → configures → updates → restarts app → changes persist and appear in Customer App.

---

## 5. Batch 2 — Digital Menu Management (P0)

### Features
- [ ] Category create / edit / delete / reorder
- [ ] Item create / edit, name, description, price
- [ ] Food photos (Batch 5)
- [ ] Availability toggle; publish / unpublish
- [ ] Dietary info where the schema supports it
- [ ] Variants / add-ons only if already in schema
- [ ] Customer-facing menu preview
- [ ] Empty / loading / error states throughout

### PostgreSQL
- [ ] Menu bound to correct restaurant (and branch if applicable)
- [ ] Item bound to a valid section
- [ ] Prices stored in the correct numeric type, validated server-side
- [ ] Constraints prevent orphan items
- [ ] Availability changes persist
- [ ] Deletes respect FK dependencies (soft delete if that is the existing pattern)
- [ ] Ordering stable and consistent

### Flow to prove
`Partner edit → Express validate → PostgreSQL → Customer App published menu`

### Touch points
`lib/repositories/menu_repository.dart` · `lib/models/catalog.dart` · `lib/screens/menu/` · `server/src/routes/partner_menu.ts` · `menu_sections`, `menu_items`

---

## 6. Batch 3 — QR Code System (P0)

**Reuse, do not rebuild.** `qr_flutter` and `mobile_scanner` are already dependencies.

### Features
- [ ] Restaurant QR generation; branch-specific variant where applicable
- [ ] QR maps to a stable, canonical restaurant/branch identifier
- [ ] Opens correct public profile and digital menu
- [ ] Customer App scan path works; external camera scan works
- [ ] Web fallback if the existing scheme supports it
- [ ] Download, share, print-friendly asset
- [ ] Scan tracking only if already supported

### Constraints
- [ ] No invented domains or deep-link routes
- [ ] No new QR table unless persistence/tracking genuinely requires it
- [ ] Public QR destinations expose no private partner data

### Touch points
`lib/widgets/qr_code_view.dart` · `lib/screens/business/qr_tab.dart` · existing QR widget tests (`test/widget/qr_code_view_test.dart`, `qr_tab_test.dart`) · backend restaurant lookup by identifier

---

## 7. Batch 4 — Deals & Promotions (P0)

### Features
- [ ] Create / edit / delete / deactivate
- [ ] Percent or fixed discount per existing schema
- [ ] Start and expiry dates; applicable branches
- [ ] Deal images (Batch 5)
- [ ] Activate / pause
- [ ] Scheduled, active, expired, inactive views
- [ ] Eligibility rules; discount and date validation
- [ ] Active deals surface in Customer App

### Backend & PostgreSQL
- [ ] Ownership and deal↔restaurant FK verified
- [ ] Server-side date validation and expiry handling
- [ ] Safe status transitions (reuse existing transition map pattern)
- [ ] Duplicate submission prevention
- [ ] Correct public visibility filter

### Touch points
`lib/repositories/business_repository.dart` · `lib/models/deals.dart` · `test/models/deals_test.dart` · `server/src/routes/partner_ops.ts` · `restaurant_deals`

---

## 8. Batch 5 — Secure Image Upload System (P1)

**Shared dependency.** Ship a minimal secure upload when Batch 1/2/4 first need it, then generalize here.

### Scope
Restaurant logo · cover · gallery · menu/food · promotional · experience images

### Implement
- [ ] Prefer an existing backend upload path if one exists
- [ ] Otherwise a single secure Express upload endpoint + file storage consistent with existing infra
- [ ] No large binaries in PostgreSQL — store files, persist references
- [ ] Flutter image picker; MIME + size validation client and server
- [ ] Safe/generated object keys; path traversal blocked
- [ ] Compression / resize
- [ ] Upload progress, retry, failure handling
- [ ] Secure access to stored files
- [ ] Replace and remove flows, with reference cleanup
- [ ] Reference persisted to the correct columns

### Touch points
New: `lib/services/image_upload_service.dart`, `lib/widgets/image_upload_field.dart`, `server/src/routes/uploads.ts`, storage dir/config · existing columns: `venues.cover_image`, menu item `photo_url`, deal image, experience image

---

## 9. Batch 6 — Reservations & Dining Experiences (P1)

**Reuse the existing repositories.** Empty `lib/screens/bookings/` and `lib/screens/events/` do not prove missing functionality — trace navigation and sheets first; reservation screens may live under `service` tabs.

### Reservations
- [ ] List, detail, upcoming vs past
- [ ] Accept / decline where supported
- [ ] Status transitions via `kReservationTransitions` + `Reservation.allowedActions` (never hardcode button lists)
- [ ] Availability management
- [ ] Cancellations; invalid transitions blocked server-side
- [ ] Customer ↔ partner state stays consistent

### Experiences
- [ ] Host requests list; approve / decline
- [ ] Upcoming experiences; participant and booking info
- [ ] Authorized detail edits
- [ ] Guest check-in (QR encodes booking reference → resolve to booking id from cached list, then `POST /partner/bookings/:id/checkin`)
- [ ] Experience status updates; related notifications

### Touch points
`lib/repositories/operations_repository.dart` · `lib/repositories/experience_repository.dart` · `lib/models/operations.dart` · `lib/models/experience.dart` · `test/models/reservation_transitions_test.dart` · `server/src/routes/partner_tables.ts`, `partner.ts` · `reservations`, `dining_tables`, `dinner_events`, `event_bookings`

---

## 10. Batch 7 — Dashboard, Analytics & Notifications (P1)

### Dashboard
Real PostgreSQL-backed metrics only — **never fabricate numbers**:
- [ ] Profile/verification status
- [ ] Active menu items; active promotions
- [ ] QR scans (only if tracked)
- [ ] Profile views (only if tracked)
- [ ] Upcoming reservations; experiences
- [ ] Recent notifications; engagement where available

### Analytics
- [ ] Reuse existing `/partner/analytics` endpoint
- [ ] Verify each metric against its actual SQL
- [ ] Date filtering and lightweight visualization where supported
- [ ] No speculative analytics expansion

### Notifications
- [ ] Listing, read/unread, mark one / mark all
- [ ] Booking, experience, restaurant alerts
- [ ] Socket.IO updates through the **existing** service only (`websocket_service.dart`)
- [ ] Reconnection behavior verified
- [ ] Restaurant-level access control on notification reads

### Touch points
`lib/screens/dashboard/dashboard_screen.dart` · `lib/screens/business/analytics_tab.dart` · `lib/screens/inbox/notifications_screen.dart` · `lib/models/finance.dart` · `lib/models/comms.dart` · `lib/services/websocket_service.dart` · `server/src/routes/partner_ops.ts`, `partner.ts`

---

## 11. Cross-Cutting — Staff, Roles & Multi-Branch Permissions

- [ ] Owner / manager / staff capability matrix verified against `requireVenueRole`
- [ ] Staff invite, accept, role change, removal
- [ ] Branch assignment and branch-scoped operations
- [ ] Restaurant switching resets scope correctly
- [ ] Menus, deals, reservations each respect the capability ladder
- [ ] **Never trust** role / restaurant id / branch id from the client — verify via `restaurant_staff` membership
- [ ] Cross-restaurant access attempts tested and rejected

---

## 12. Cross-Cutting — PostgreSQL Rules (all batches)

1. Existing pool only. 2. Parameterized SQL only. 3. Reuse tables. 4. Verify column names before writing SQL. 5. Respect FKs. 6. Transactions for multi-step atomic writes. 7. No duplicate writes. 8. Paginate large collections. 9. Index only where justified. 10. No raw SQL errors to clients. 11. Flutter never touches PostgreSQL. 12. No second database. 13. Versioned migrations. 14. Test on dev DB first. 15. Approval before production.

---

## 13. Customer App Integration Matrix (must be proven, not assumed)

| Partner action | Expected customer-visible result |
|---|---|
| Register restaurant | Discoverable once approved/published |
| Update profile | Updated public profile |
| Add category | Category appears in menu |
| Add menu item | Published item appears |
| Update price | Correct price shown |
| Mark unavailable | Availability updates |
| Create promotion | Eligible active promotion appears |
| Expire promotion | No longer listed as active |
| Generate QR | Scan opens the correct restaurant |
| Confirm reservation | Customer sees new status |
| Update experience | Permitted changes visible |

Also verify: compatible contracts, shared record identity, consistent restaurant ids, cache invalidation, unpublished/deleted handling, auth vs public endpoint separation, consistent errors, existing Socket.IO reuse.

---

## 14. Flutter UI/UX Reliability

Preserve the Inter / dark / amber theme. Functional polish only:

- [ ] Correct navigation (including query-bearing tabs)
- [ ] All buttons wired; forms validated
- [ ] Loading, empty, error, success, retry states
- [ ] Responsive layouts, safe areas, keyboard-aware forms
- [ ] Image placeholders, correct scroll behavior, consistent touch targets

Device matrix: small (~320dp), standard, large. Fix RenderFlex overflow, clipped buttons, horizontal overflow, keyboard overlap, broken modals, unresponsive forms, bad image sizing. **No full visual redesign.**

---

## 15. Security & Reliability Testing

**Auth/authz:** valid, expired, unauthorized, ownership, staff perms, cross-restaurant denial.
**API/DB:** CRUD, invalid input, missing records, duplicate requests, DB failure, transaction rollback, concurrent updates, FK integrity, safe errors.
**Mobile:** navigation, form submit, loading, network errors, session persistence, uploads, QR, multiple screen sizes.
**Cross-app:** profile, menu, deal, reservation sync; QR navigation.

Use dev/staging data. No destructive tests on production records. Never bypass auth to make a test pass.

---

## 16. Execution Order & Timeline

| Batch | Module | Priority | Days |
|---|---|---|---|
| 0 | Architecture verification | — | 0.5–1 |
| 1 | Restaurant & Café Management | P0 | 2–3 |
| 2 | Digital Menu Management | P0 | 2–3 |
| 3 | QR Code System | P0 | 1–2 |
| 4 | Deals & Promotions | P0 | 2–3 |
| 5 | Image Upload System | P1 | 2–3 |
| 6 | Reservations & Experiences | P1 | 2–3 |
| 7 | Dashboard, Analytics & Notifications | P1 | 2–3 |

Per batch: inspect → identify gap → implement frontend → implement/repair Express → integrate PostgreSQL → verify Customer App → add tests → run tests → fix → document.

Do not repeat completed work. Do not advance a batch while a critical defect is open.

---

## 17. Deliverables

**A. Module Completion Matrix** — Working / Partial / Broken / Missing / Unverified, columns: Flutter · Express API · PostgreSQL · Customer App · Tests.

**B. Implementation Summary** — completed features, fixed defects, modified files, new/repaired endpoints, migrations, security improvements, test results, remaining dependencies.

**C. Remaining Backlog** — P0 / P1 / P2 / P3.

Save as `PHASE3_COMPLETION_REPORT.md` in `partnerapp/`.

---

## 18. Definition of Done

- [ ] Restaurant registration & management work
- [ ] Restaurant and menu image uploads work
- [ ] Digital menu management works
- [ ] Menu changes appear correctly in the Customer App
- [ ] QR codes open correct restaurant menus
- [ ] Deals and promotions work end-to-end
- [ ] Reservations and experiences work where supported
- [ ] Staff and branch permissions enforced
- [ ] Dashboard shows real business data
- [ ] Notifications work via existing infrastructure
- [ ] PostgreSQL operations secure and consistent
- [ ] Core APIs have passing tests
- [ ] Cross-app synchronization verified
- [ ] No critical navigation or layout errors
- [ ] No unresolved P0 security or data-integrity defects

Evidence required per item. Phase 4 (subscriptions, billing, plans, monetization) does **not** start automatically.

---

## 19. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Phase 2 not actually finished → building on unverified auth/RLS assumptions | Gate Batch 1 on Stage 0 completion; record unverified areas explicitly |
| Dev Postgres cluster dies after reboot | Re-init/start `~/.local/share/dinecircle/pgdata` on 5433, then `npm run db:setup` if schema/seed missing |
| Scope creep into monetization | Subscriptions/billing/Stripe are Phase 4 — out of scope here |
| Duplicate endpoint creation to work around contract mismatch | Fix the smallest correct layer; never add a parallel endpoint |
| Rebuilding working screens | Inventory existing screens/navigation before writing anything new |
| Image uploads ballooning | Minimal secure path first, generalize once, no per-module upload code |
| UI overflow regressions on small devices | Test at 320dp and 2.0× text scale; treat grid height as a floor |

---

## 20. Immediate First Steps

1. Confirm Phase 2 status; list any unverified areas carried forward.
2. Start Postgres (`pg_isready -h 127.0.0.1 -p 5433`) and the API (`npm start`), verify `/api/health`.
3. Run Stage 0 inspection and write the architecture snapshot.
4. Export the actual table list (`\dt`) and reconcile against `server/database/schema.sql`.
5. Inventory Partner App screens and navigation routes vs. the batch feature lists.
6. Begin Batch 1.

**Next phase:** Phase 4 — Subscriptions, billing, plan management, monetization.
