================================================================================
PART 1: ENGINEERING CORE PROTOCOLS
================================================================================
[INSTRUCTION: The following protocols are non-negotiable. Any deviation requires explicit, documented sign-off.]

## 1. TEST-DRIVEN DEVELOPMENT (THE IRON LAW)
* **The Iron Law:** NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
* **The Cycle (Strictly Enforced):**
  1. **RED:** Write a test that fails for the expected reason (e.g., Assertion Error, not Compilation Error).
  2. **GREEN:** Write the simplest code to pass. Hardcoding is acceptable here.
  3. **REFACTOR:** Clean up (DRY, naming) only while Green.
* **Violations (Anti-Patterns):**
  * *The Batcher:* Writing >1 test at a time is banned.
  * *The Mock-Everything:* Mocking internal details instead of boundaries is prohibited.
* **Spike Protocol (Prototyping Sandbox):**
  * **Allowed Sandbox Zones:** `experimental/` directories and files ending in `.proto.<ext>` (examples: `.proto.dart`, `.proto.tsx`).
  * **Temporary Exception:** Inside sandbox zones only, the Iron Law and full Pre-Flight Audit may be suspended while interface/logic is still unsettled.
  * **Containment Rule:** Production code in `src/` (or equivalent) must not depend on sandbox artifacts.
  * **Stabilization Gate:** Before commit/merge, spike code must be refactored into production paths with accompanying tests. `lefthook.yml` enforces a commit-blocking proto-file check.
  * **Ephemerality Rule (Mandatory):** Spike artifacts may not persist across more than one feature branch lifecycle. They are disposable prototypes, not long-lived local dependencies.
  * **Staleness TTL (Tooling):** `scripts/enforce_exclusion_zones.ps1` and `scripts/enforce_exclusion_zones.sh` must warn on spike artifacts older than 48 hours (configurable via `CARIS_SPIKE_STALE_HOURS`). CI may escalate this to a hard failure with `CARIS_FAIL_ON_STALE_SPIKES=1`.
  * **Stale Spike Recycling Workflow (Mandatory when flagged):**
    1. Analyze the stale spike artifact and list reusable domain logic vs throwaway scaffolding.
    2. Generate a TDD migration plan targeting the production path (`lib/`, `src/`, etc.).
    3. Re-implement the reusable logic in production code with failing tests first.
    4. Verify behavior parity and add error handling/logging/telemetry.
    5. Delete the stale spike artifact after production migration succeeds.
  * **Stale Spike Refactor Prompt Template (Recommended):** "Analyze `[SPIKE_FILE]`, extract the core logic worth preserving, and propose a TDD migration plan to `[PRODUCTION_PATH]` with tests, error handling, and cleanup steps. Do not copy spike code directly into production."

## 2. SYSTEMATIC DEBUGGING
* **Core Principle:** Fixes without root cause investigation are considered failures.
* **Phase 1 (Investigation):** Read stack traces fully. Reproduce consistently. Trace data flow.
* **Phase 2 (Pattern Analysis):** Compare against working examples. Check environment/dependencies.
* **Phase 3 (Hypothesis):** Form a single hypothesis ("I think X because Y"). Test minimally.
* **Phase 4 (Implementation):** Write a failing test case. Apply atomic fix. Verify no regressions.

## 3. CODE REVIEW & ROUTING PROTOCOLS
* **Reception Strategy:** Verify before implementing. Do not "performative agree". Push back on suggestions that violate YAGNI or introduce complexity.
* **Implementation Order:** 1. Blocking Issues (Security/Bugs) → 2. Simple Fixes → 3. Complex Refactors.
* **Automated Routing Logic:**
  * *Low Complexity (Score < 5):* Route to Fast Model for typos and formatting.
  * *Medium Complexity (Score 5-20):* Route to Standard Model for single component logic.
  * *High Complexity (Score > 20):* Route to Reasoning Model for Architecture, Security, and Migrations.
* **Tiered Audit Routing (Pre-Flight Audit):**
  * *Self-Certify Path:* If complexity score is `< 5` and no high-risk files are touched, the AI may execute immediately after recording a short self-certification.
  * *High-Risk Override:* Full "Stop-and-Think" audit + human review is mandatory when touching exclusion-zone enforcement, system constitution/governance docs, or SQL/Prisma schemas/migrations.
  * *Semantic Risk Override:* Low cyclomatic complexity does NOT imply safety. `scripts/complexity_gate.py` must also inspect changed file content for semantic triggers (e.g., payment/auth/password/encryption/billing/refund keywords) and force Stop-and-Think when detected.
  * *Mechanism:* `scripts/complexity_gate.py` is the routing authority and must output both complexity route and audit route.

## 4. GIT ADVANCED WORKFLOWS
* **Interactive Rebase:** Use `git rebase -i HEAD~N` to squash, reword, or drop commits before merging.
* **Bisect:** Use `git bisect start` → `bad` → `good` to execute a binary search for bug-introducing commits.
* **Worktrees:** Use `git worktree add ../new-feature` to allow parallel branch work without context switching.
* **Reflog Recovery:** Use `git reflog` → `git reset --hard HEAD@{n}` to recover lost commits or branches.

================================================================================
PART 2: TECHNICAL DOMAIN GUARDS
================================================================================

## 1. MODERN PYTHON & TESTING
* **Package Management (UV):** Use `uv init <project>`, `uv add <package>`, and `uv run script.py`. This replaces pip/poetry and mandates ephemeral environments.
* **Testing (Pytest):** * Structure tests using Arrange-Act-Assert (AAA). 
  * Use `yield` for teardown in fixtures and `scope="session"` for databases. 
  * Use `@pytest.mark.parametrize` to avoid loops in tests. 
  * Patch external dependencies using `unittest.mock`, never the Unit Under Test (UUT).

## 2. FRONTEND DESIGN AESTHETICS (THE "ANTI-SLOP" MANDATE)
* **The Core Directive:** Build distinctive, production-grade interfaces that avoid generic "AI slop" layouts and boilerplate styling.
* **Token-First Rule (Mandatory):** Anti-slop decisions must be selected from the locked design token schema in `002c_UNIVERSAL_ARCH_BLUEPRINT.md` (font pair enum, typography ratio, spacing, texture IDs). Do not rely on subjective adjectives alone.
* **Token Enforcement Rule (Mandatory):** The token schema is not advisory. `scripts/design_token_guard.py` (plus framework lint rules, e.g., Flutter `custom_lint`) must hard-fail raw color literals and off-scale typography values. Optional autofix may rewrite raw CSS hex literals to token references.
* **Typography:** Generic fonts like Arial, Roboto, and Inter remain banned unless explicitly whitelisted in the active token schema/profile for body text. Use a whitelisted display/body pair only.
* **Color & Atmosphere:** Use CSS variables/theme tokens. Cliched purple-on-white defaults are banned. Atmospheric depth must use whitelisted texture assets from `004_EXTERNAL_LIBS_AND_RESOURCES.md` when available.
* **Spatial Composition & Layout:** Layouts may be bold, but the selected token/profile constraints (spacing grid, touch targets, typography scale) are non-negotiable.
* **Motion & Interactions:** Favor a few high-impact moments over scattered micro-interactions. Use stack-approved libraries (or CSS) per framework profile.
* **Execution Constraint:** Implementation complexity must match the selected token profile and aesthetic target without breaking usability or accessibility.

## 3. SQL OPTIMIZATION
* **Diagnostics:** Always run `EXPLAIN (ANALYZE, BUFFERS)` to hunt for `Seq Scan` on large tables.
* **Indexing Mandates:** Use B-Tree for standard comparisons, GIN for JSONB/Arrays/Full-Text Search, and BRIN for massive time-ordered logs.
* **Anti-Patterns:** Fix N+1 Queries with JOINs or `WHERE id IN (...)`. Fix Offset Pagination with Keyset Pagination (`WHERE id > last_seen LIMIT 20`). Fix Wildcard Leading (`LIKE '%term'`) with Trigram Index (`pg_trgm`).

================================================================================
PART 3: AGENT SKILLS ARCHITECTURE
================================================================================

## 1. SKILL STRUCTURE & DISCOVERY
* **Definition:** A skill is a directory containing a `SKILL.md` file.
* **Constraints:** `SKILL.md` must be < 500 lines; heavy documentation goes into `references/`. Agents scan directories, parse frontmatter, and inject metadata into the system prompt.
* **Spec:** Frontmatter must be YAML containing name (max 64 chars), description (max 1024 chars), and compatibility.

## 2. STANDARD SKILLS
* **Plan Creation (`create-plan`):** Operates in Read-only mode, asks max 1-2 questions, and outputs a specific Markdown template with Scope, Action Items, and Open Questions.
* **Linear Integration (`linear`):** Workflow strictly follows: Clarify Goal → Select Tool → Execute (Read then Write) → Summarize.

================================================================================
PART 4: THE PRE-CODE AUDIT (CONSTRAINT-FIRST ARCHITECTURE, TIERED)
================================================================================
[INSTRUCTION TO AI: Do not assume every task requires a full human-halt audit. First determine the audit route using complexity and risk. Low-complexity, low-risk changes may self-certify. High-risk or high-complexity changes require the full "Stop-and-Think" audit before code.]

TIERED AUDIT ROUTING (MANDATORY)
1. Compute/obtain the complexity route (see `scripts/complexity_gate.py`).
2. Detect high-risk file classes:
   - Exclusion-zone enforcement or guardrail configs (`scripts/enforce_exclusion_zones.*`, `lefthook.yml`, CI gate configs).
   - System constitution / governance docs (`001` through `005` architecture and protocol documents).
   - Database schemas and migrations (`*.sql`, `*.prisma`, `migrations/`).
   - Semantic risk triggers in changed file contents (`payment`, `auth`, `password`, `encryption`, `billing`, `refund`, etc.) even when complexity is low.
3. Routing Outcome:
   - **Self-Certify (Fast Path):** Complexity `< 5` and no high-risk paths. AI records a short audit line, then proceeds without waiting.
   - **Standard Audit:** Complexity `5-20` and no high-risk paths. AI outputs a concise Pre-Flight Audit, then may proceed unless local rules require approval.
   - **Stop-and-Think Audit (Mandatory Human Review):** Any high-risk path OR complexity `> 20`.

THE PRE-FLIGHT AUDIT TEMPLATE (FULL FORM)
Use this form for Standard or Stop-and-Think routes. For Self-Certify, output only the short routing line and proceed.

0. Audit Routing Decision
Complexity Route: [Fast / Standard / Reasoning] (Score: [N])
High-Risk Paths Touched: [None | list exact files]
Audit Route: [Self-Certify / Standard Audit / Stop-and-Think]

1. Architectural Alignment
Execution Boundary: [Is this running on the Server, the Client, or Both? Why?]

State Management: [Where does the state live? Local hook, global store, URL params, or persisted draft store?]

2. The "Horror Path" Defense (Active Recovery + Restoration)
Network Collapse: [How will this code behave if the database or 3rd-party API takes 10 seconds to respond or returns a 503?]

Recovery Pattern: [Circuit Breaker / Exponential Backoff / Both. Name the wrapper or library.]

State Restoration: [What user input is persisted locally before the mutation? How is the pre-submit state restored after failure?]

Poisoned Payload: [How are we validating the data entering this function? What happens if a user submits a 50MB malformed JSON blob?]

Concurrency / Race Conditions: [What happens if two users trigger this exact mutation at the exact same millisecond?]

3. Explicitly Banned Patterns
Anti-Pattern Acknowledgment: [State 1-2 lazy ways an AI would normally write this (e.g., "Using an N+1 query loop" or "Exposing the raw stack trace in the catch block").]

The Caris Stack Solution: [State exactly how you will avoid the anti-pattern using the rules defined in documents 001 through 004.]

[AI STOP POINT - ONLY FOR STOP-AND-THINK]: "I have completed the Pre-Code Audit. Please review. Shall I proceed with generating the code?"
