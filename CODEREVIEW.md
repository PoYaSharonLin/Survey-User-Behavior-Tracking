You are reviewing a research-grade Ruby (Roda + Sequel) + Vue 3 fullstack application
called "Survey-User-Behavior-Tracking". It is a master's thesis project that records
fine-grained user behavior (mouse movement, clicks, keystrokes, scroll, text highlights,
slider interactions) during an online survey. The backend follows Domain-Driven Design (DDD).

Please read through the repository and produce a structured review covering all 10
dimensions below. For each finding, cite the specific file and line number.

---

## Dimension 1: Readability & Style

Review naming clarity, formatting consistency, and adherence to language style guides.

Focus on:
- **Style guide compliance**: Does the Ruby backend follow RuboCop conventions? Does the
  Vue/JS frontend follow ESLint rules? Check for any `# rubocop:disable` annotations in
  `backend_app/` and assess whether they are justified or working around real issues.
- **Naming consistency**: `record_events.rb` — the class comment says "Records one or
  many *trajectories*", but the class itself is `RecordEvents`. The word "trajectories"
  is a leftover from an earlier schema design (see migration history). Does this
  residual terminology cause confusion for a new developer?
- **Naming consistency across layers**: The ORM model is `BehaviorEvent` (singular), the
  repository is `BehaviorEvents` (plural), the route file is `behavior.rb`, and the
  domain entity is also `BehaviorEvent`. Is this consistent with how other resource
  pairs are named in the codebase?
- **Function length**: `submit()` in `PostSurvey.vue` is over 60 lines and implements
  a 5-step upload flow inline. Does its length hurt readability?

---

## Dimension 2: Code Quality

Review for duplicated logic, single-responsibility violations, and unnecessary complexity.

Focus on:
- **Single Responsibility Principle**: `create_session.rb` — `CreateSession` both creates
  a session record and triggers an S3 upload. Is session persistence and data export the
  same responsibility? What is the impact on cohesion?
- **DRY**: `PostSurvey.vue` and `SurveyPage.vue` share near-identical slider + confirm-
  button markup for each question. Is there an abstraction opportunity being missed?
- **Dead code**: `upload_session_data` in `s3_service.rb` uploads a `.json` file to S3
  and returns a `{ success, key }` hash — but the caller in `CreateSession` ignores the
  return value entirely and never stores the `.json` key anywhere. Is this method
  effectively dead from the researcher's perspective? Compare with the `.bin` path, where
  the key is persisted via `confirm-upload`.
- **Nesting and complexity**: The 5-step `submit()` in `PostSurvey.vue` has deeply nested
  `await` calls with a single catch at the bottom. Does the control flow make it easy to
  reason about which steps have and haven't completed when an error is thrown?

---

## Dimension 3: Correctness

Review for logic errors, unhandled edge cases, and type/boundary issues.

Focus on:
- **Dual metadata trigger**: `session.js` always passes a `metadata` object
  (`user_agent`, `referrer`, `viewport_width`, `viewport_height`) to
  `POST /api/survey/session` on every page load. `CreateSession` interprets
  `if metadata` as the signal to trigger `upload_session_data`. The only accidental guard
  preventing spurious S3 uploads is `return if events.empty?` inside `upload_session_data`.
  Is this the intended design, or should "survey submitted" be signalled differently
  (e.g. a dedicated field or endpoint)?
- **Non-atomic 5-step submit**: `PostSurvey.vue` `submit()` runs:
  step 1 (session metadata) → step 2 (presign) → step 3 (S3 PUT) → step 4 (confirm) →
  step 5 (smoke-test download). If step 3 succeeds but step 4 fails, the blob is in S3
  but `s3_key` is never written to the DB. The researcher has no record of where the
  file is. Is there a recovery path?
- **Retry creates duplicate blobs**: `errorMsg` on catch allows the user to retry
  submission. Because the S3 key includes `Time.now.to_i`, each retry generates a new
  key and a new blob. Multiple orphaned blobs may accumulate in S3 for the same session.
- **`respondent_id` validation gap**: `CreateSession` checks `nil?` and `strip.empty?`,
  but the value is later embedded directly into an S3 key
  (`"behavior_data/#{respondent_id}_#{Time.now.to_i}.bin"`). No length or character
  validation is applied. What happens with respondent IDs containing special characters?
- **Stale `hoverMap` on restart**: `tracker.js` — `hoverMap` is not cleared in `stop()`.
  If `stop()` and `start()` are called in quick succession (e.g. page navigation within
  a SPA), hover start-times from the previous session may survive into the new one,
  corrupting `pointer-out` duration calculations.
- **`scroll` event coordinates**: `scroll` events record `x: lastRecordedX ?? 0,
  y: lastRecordedY ?? 0`. If the participant scrolls before moving the mouse,
  both coordinates are `0`. Is this a known approximation or an unintended edge case?

---

## Dimension 4: Error Handling

Review for silent failures, meaningless error messages, and unhandled exception paths.

Focus on:
- **Silent S3 failure in `CreateSession`**: the `rescue StandardError` block on line 38
  only calls `puts "[S3 Export Failed] #{e.message}"`. There is no log level, no request
  ID, and no way to query these failures after the fact. A researcher may never know that
  the export failed.
- **`session.js` swallows session registration errors**: `init()` catches all errors with
  `console.warn` and returns `null`. The tracker starts anyway even if the backend
  session was never created, meaning events will fail to persist (the `respondent_id`
  won't resolve to a session on the backend). The user sees no error.
- **`GET /api/survey/session/:id` has no rescue**: `survey.rb` route for the GET branch
  has no `rescue JSON::ParserError` or general rescue, unlike the POST branch. An
  unexpected error would bubble up as an unhandled exception with an unformatted response.
- **`tracker.js` flush retry is unbounded**: on HTTP failure, `rawQueue.unshift(...batch)`
  re-queues the batch with no retry limit or backoff. If the backend is down, the queue
  grows indefinitely; when the backend recovers, one oversized batch floods the endpoint.
- **`localStorage` failures silently skip**: `savePersistedHistory` catches quota-exceeded
  errors and silently continues, but `fullHistory` in memory keeps growing. The user
  gets no warning, and the binary export at submit time will reflect the full in-memory
  history — which may differ from what was actually persisted to `localStorage`.

---

## Dimension 5: Security

Review for authentication gaps, injection vectors, and sensitive data exposure.

Focus on:
- **No authentication or authorization on any endpoint**: All API routes are fully public.
  Anyone who knows a `respondent_id` can read that user's session
  (`GET /api/survey/session/:id`), inject arbitrary fake events into their record
  (`POST /api/behavior/:id/events`), and generate a presigned URL to download their raw
  behavior blob (`GET /api/behavior/:id/download-url`). Is this acceptable for a research
  deployment where participant data must be protected?
- **`confirm-upload` accepts arbitrary S3 keys from the client**: the endpoint stores
  whatever `key` the client sends with no validation that it begins with `behavior_data/`
  or belongs to the requesting `respondent_id`. An attacker could overwrite another
  user's stored key or point it at an unrelated S3 path.
- **Unsanitized `respondent_id` in S3 key**: `s3_service.rb` builds the key as
  `"behavior_data/#{respondent_id}_#{Time.now.to_i}.bin"` with no encoding or
  validation. A `respondent_id` containing `../` or URL-special characters produces
  unexpected key names.
- **Presigned S3 URLs logged to browser console**: `PostSurvey.vue` contains six
  `console.log` calls that print the presigned upload URL, presigned download URL, and
  their expiry times. Anyone with DevTools open during submission captures a live,
  usable download URL. These must be removed or gated on a development flag before
  deployment.
- **Key-down recording scope**: `tracker.js` records `key`, `code`, and all modifier
  flags for every keypress. If any future survey page adds a free-text input, this
  silently captures everything the participant types.
- **`navigator.userAgent` stored as session metadata**: in GDPR-applicable jurisdictions,
  `userAgent` combined with a persistent `respondent_id` may constitute personal data.
  Is there a data processing agreement or IRB protocol that covers this collection?

---

## Dimension 6: Performance

Review for unnecessary computation, risky query patterns, and memory growth.

Focus on:
- **Flush rate**: `FLUSH_INTERVAL = 100ms` in `tracker.js` means up to 10 HTTP requests
  per second per active participant. With N concurrent participants this is 10N
  requests/second to a single Roda process with no rate limiting. Has this been load-
  tested against the expected participant count?
- **`fullHistory` memory growth**: `fullHistory` accumulates every event for the entire
  session with no upper bound. High-frequency pointer-move events on a long survey could
  produce tens of thousands of entries. `savePersistedHistory` serializes the entire array
  to `localStorage` on every flush. At what point does this exhaust the 5 MB localStorage
  quota, and what is the impact when it does?
- **`list_by_session` hard-coded limit**: `behavior_events.rb` `list_by_session` has
  `limit: 5000`. For a high-activity session this silently truncates the result. The
  caller (`upload_session_data` in `CreateSession`) does not check whether the result was
  truncated, so the exported `.json` file may be incomplete with no indication.
- **Race condition on session creation**: `SurveySessions` `find_or_create` runs two
  separate queries (find → create) without a database-level unique constraint enforced
  at query time. Under concurrent requests with the same `respondent_id`, both could pass
  the find step and attempt to create, hitting the unique constraint at the DB level.
  How is this constraint violation surfaced to the caller?
- **S3 key timestamp collision**: both upload paths use `Time.now.to_i` (second
  precision) to derive the S3 key. Two uploads within the same second produce the same
  key, and the second PUT silently overwrites the first. The `s3_key` column stores only
  one key per session, so the first upload is unrecoverable.

---

## Dimension 7: Testability

Review for test coverage gaps and code structures that resist unit testing.

Focus on:
- **Untested backend routes**: the following endpoints have zero test coverage:
  - `GET /api/behavior/:id/presigned-url`
  - `POST /api/behavior/:id/confirm-upload`
  - `GET /api/behavior/:id/download-url`
  - Error branches in `RecordEvents` (invalid type, empty array, unknown `respondent_id`)
- **No S3 interaction tests**: `S3Service` is never mocked in the test suite. Tests that
  exercise `CreateSession` with a `metadata` payload will attempt a live S3 call (or
  silently swallow the error). Is there a test-environment stub for S3?
- **Zero frontend tests**: `tracker.js`, `session.js`, and `PostSurvey.vue` (including
  the 5-step submit flow) have no tests. The `getBinaryBlob()` binary format — with its
  SBEH magic bytes, uid-length header, and msgpack payload — is completely untested.
  How would a format regression be detected?
- **Singleton tracker resists unit testing**: `tracker.js` exports a module-level
  singleton with mutable state (`userId`, `rawQueue`, `fullHistory`, `hoverMap`).
  Tests must manually reset all state between runs, and parallel test execution is unsafe.
  Would a factory function or class instantiation make this easier to test in isolation?

---

## Dimension 8: Maintainability & Extensibility

Review for magic numbers, SOLID adherence, and how easy future changes are.

Focus on:
- **Magic numbers scattered across the codebase**: the following literals appear without
  named constants or configuration:
  - `100` (flush interval ms) — `tracker.js`
  - `1` (minimum movement px) — `tracker.js`
  - `5000` (row limit) — `behavior_events.rb`
  - `600` (presigned upload expiry, seconds) — `s3_service.rb`
  - `3600` (presigned download expiry, seconds) — `s3_service.rb`
  - `1000` (minimum spinner duration, ms) — `PostSurvey.vue`
  Changing any of these requires hunting across files.
- **Schema drift with no version marker**: `behavior_events.event` stores raw JSON from
  the frontend with no schema version field. When the frontend adds or renames a field
  (e.g. `ts` → `timestamp_ms`), old and new event shapes coexist in the same column
  silently. Any analysis script must handle both shapes without knowing which rows are
  which vintage.
- **`data-track` rename is a breaking change for existing data**: the 2026-04-24 refactor
  standardized all `data-track` values to `{prefix}-{role}`. Historical data in S3 uses
  the old names. Any analysis script that filters by element name must maintain a
  translation table. Is this documented anywhere beyond `DECISION.md`?
- **`ended_at` is never set**: `update_ended_at` exists in `SurveySessions` repository
  but is never called from any route or service. Session duration and abandoned-session
  detection are permanently unavailable unless this is wired up. Is this a known gap?
- **`export_data.rb` references the pre-migration schema**: the script queries
  `:trajectories`, `:trajectory_type`, and `:events` — all replaced by migration 006.
  Running it against the current DB raises a runtime error. A researcher relying on this
  script gets no data and an unhelpful error message.

---

## Dimension 9: Dependencies & Architecture

Review for DDD layering violations, unnecessary cross-layer dependencies, and circular
references.

Focus on:
- **Application layer reaching into Infrastructure directly**: `create_session.rb` calls
  `Infrastructure::S3Service.new` directly from the Application service layer. In strict
  DDD this coupling should be inverted — the Application layer should depend on a Port
  (interface), with the S3Service as an Adapter injected at runtime. How does this affect
  testability and replaceability of the storage backend?
- **Route bypassing the service layer**: `behavior.rb` — the `confirm-upload` and
  `download-url` handlers call `Database::Repository::SurveySessions` directly from the
  route, skipping the service layer entirely. Other routes go through services. Is this
  inconsistency intentional?
- **`session.js` violates single responsibility**: `init()` reads the URL, writes to
  `localStorage`, and makes an HTTP request all in one function. Side effects are
  interleaved with data access, making it difficult to test the session-resolution logic
  independently from the network call.
- **Binary format defined in the frontend only**: the SBEH format (magic bytes, uid-length
  prefix, msgpack payload) is specified only in a `getBinaryBlob()` comment in
  `tracker.js`. Any decoder (Python/R analysis script) must derive the spec from reading
  frontend JS. Is there a canonical format document that lives outside the frontend
  source?

---

## Dimension 10: Documentation & Comments

Review for missing API documentation, comment quality (why vs. what), and TODO hygiene.

Focus on:
- **TODO/FIXME tracking**: search the codebase for `TODO`, `FIXME`, and `HACK` comments.
  Do any of them reference a ticket or issue for follow-up, or are they free-floating?
- **Comments explain what, not why**: `tracker.js` documents every event type's field
  shape (the *what*), but does not explain key design rationales: why 100 ms flush
  interval, why `MIN_DISTANCE = 1 px`, why page coordinates instead of viewport
  coordinates (this last one is in `DECISION.md` but not at the call site). Would an
  inline reference to `DECISION.md` help a future developer?
- **SBEH binary format undocumented outside frontend**: the format is described only in
  a JS comment. A Python/R researcher who needs to decode the S3 binary blob must read
  the frontend source. Is there a language-neutral format spec (e.g. in `DECISION.md`
  or a `docs/` file)?
- **`DECISION.md` gap for the trajectory-era pivot**: the file documents the 2026-04-24
  refactor thoroughly, but the earlier and more significant pivot — from typed-column
  `behavior_events` → `trajectories` (compact JSON array per row) → back to
  `behavior_events` (single JSON column per row) — has no decision entry. A new
  developer reading the migration history has no context for why the schema changed twice.
- **S3 dual-path and `s3_key` ambiguity**: there is no comment in `survey_sessions`
  schema or repository explaining that `s3_key` may point to either a `.json` file
  (from `upload_session_data`) or a `.bin` file (from `confirm-upload`), or explaining
  which format to expect. A researcher downloading the file has no in-code guidance.

---

## Deliverable

Please produce a structured report with:
- A severity rating for each finding: **Critical / Major / Minor / Info**
- A concrete suggested fix or mitigation for every Critical and Major finding
- A summary table at the end with columns:
  **Dimension | Finding | Severity | File:Line**

You do not need to run the code — read the source files directly.

Key files to read (in recommended order):
1. `backend_app/db/migrations/` — all 7 files (understand schema history first)
2. `backend_app/app/domain/behavior_events/entities/behavior_event.rb`
3. `backend_app/app/domain/survey_sessions/entities/survey_session.rb`
4. `backend_app/app/application/services/survey_sessions/create_session.rb`
5. `backend_app/app/application/services/behavior_events/record_events.rb`
6. `backend_app/app/infrastructure/database/repositories/behavior_events.rb`
7. `backend_app/app/infrastructure/database/repositories/survey_sessions.rb`
8. `backend_app/app/infrastructure/s3_service.rb`
9. `backend_app/app/application/controllers/routes/behavior.rb`
10. `backend_app/app/application/controllers/routes/survey.rb`
11. `backend_app/export_data.rb`
12. `backend_app/spec/routes/behavior_route_spec.rb`
13. `backend_app/spec/routes/survey_route_spec.rb`
14. `frontend_app/lib/tracker.js`
15. `frontend_app/lib/session.js`
16. `frontend_app/pages/PostSurvey.vue`
17. `frontend_app/pages/SurveyPage.vue`
18. `DECISION.md`
