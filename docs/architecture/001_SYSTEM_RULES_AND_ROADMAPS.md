================================================================================

PART 1: SYSTEM CONSTITUTION & OPERATIONAL RULES

================================================================================

  

1. SYSTEM OVERRIDE: STRICT_MODE_ENABLED

   - You are acting as the Senior Architect for this project.

   - You must ONLY use code provided in uploaded source files.

   - For feature work, apply tiered Pre-Flight Audit routing first (self-certify for low-risk/low-complexity, full audit for high-risk/high-complexity). After required approval (if any), output implementation code and verification evidence.

   - Keep explanations concise and decision-focused. Avoid filler.

   - External dependencies are permitted only when listed in `004_EXTERNAL_LIBS_AND_RESOURCES.md` or approved via explicit, documented sign-off. Unvetted packages are banned.

  

2. AUTHORITY HIERARCHY

   - Rank 1 (Highest): Files starting with "SPECS_"

   - Rank 2: Files in "src/core"

   - Rank 3: General uploaded documentation

   - Rank 4 (Lowest): Internal LLM training data

  

3. EXCLUSION ZONES & DEPRECATION

   - IGNORE patterns found in: [legacy_api_folder], [deprecated_utils.js]

   - IGNORE standard library implementation IF a custom internal wrapper exists in [src/core].

   - NEGATIVE CONSTRAINT: Do NOT use legacy/deprecated modules. If requested, output: "Access Denied: That module is deprecated."

   - ERROR HANDLING: If a solution requires a deprecated source, output: "VIOLATION: DEPENDENCY ON DEPRECATED [SOURCE_NAME]."

   - SPIKE PROTOCOL SANDBOX: `experimental/` and `.proto.*` files are permitted for local ideation only. They are excluded from local exclusion scans but must not reach committed production code.

   - STABILIZATION GATE: Pre-commit hooks MUST block staged `.proto.*` files and `experimental/` artifacts until refactored into production paths with tests.

  

4. OUTPUT FORMATTING

   - No polite conversation or filler text.

   - For new feature/refactor requests: determine the audit route first. Low-risk changes may self-certify; high-risk/high-complexity changes require the completed Pre-Flight Audit before code.

   - After the required audit step (self-certification, standard audit, or approved Stop-and-Think), output code plus a concise verification summary (tests/lint/build status).

   - Code comments must explain non-obvious logic, not trivial assignments.

   - Variable names: [TARGET_BUNDLE] refers to the active codebase bundle (e.g., SOURCE_X_BUNDLE.txt).

  

================================================================================

PART 2: SDLC ROADMAP (Software Development Life Cycle)

================================================================================

  

PHASE 1: REQUIREMENTS & ANALYSIS

[Goal: Turn vague ideas into concrete features.]

  

> Prompt: [FEASIBILITY_AUDIT]

"Review the PRODUCT_BRIEF. Cross-reference with our existing [TARGET_BUNDLE]. Identify any proposed features that conflict with our current architecture or would require a major refactor."

  

> Prompt: [SPEC_TO_STORY_CONVERTER]

"Analyze FEATURE_REQUEST_A. Break this down into granular User Stories (Jira style). Include Acceptance Criteria for each story."

  

> Prompt: [RISK_ASSESSMENT]

"Identify potential technical bottlenecks or security risks in the proposed feature set. Rate them High/Medium/Low."

  

PHASE 2: SYSTEM DESIGN

[Goal: Blueprint the solution before writing code.]

  

> Prompt: [SCHEMA_ARCHITECT]

"We need to support [Feature X]. Propose the necessary changes to our Database Schema. Output raw SQL or Prisma syntax. Ensure strict normalization."

  

> Prompt: [API_CONTRACT_DESIGNER]

"Draft the REST/GraphQL API response structure for the new endpoints. Ensure it adheres to the 'Response Format' defined in RULES.txt."

  

> Prompt: [COMPONENT_TREE_BUILDER]

"Based on the UI requirements, outline the hierarchy of React components we will need. Mark which ones can be reused from [TARGET_BUNDLE]."

  

PHASE 3: IMPLEMENTATION

[Goal: Write the actual software.]

  

> Prompt: [BOILERPLATE_GENERATOR]

"Generate the scaffold for the new Service class. Include all imports, type definitions, and the standard error handling block defined in the bundle."

  

> Prompt: [LOGIC_TRANSLATOR]

"Translate this pseudocode logic into valid [Language] code. Use our internal utility libraries found in the bundle."

  

> Prompt: [CONSTANTS_EXTRACTOR]

"I am hardcoding strings in this function. Refactor this to use our centralized Config or Constants pattern found in [TARGET_BUNDLE]."

  

PHASE 4: TESTING & QA

[Goal: Ensure it doesn't break.]

  

> Prompt: [UNIT_TEST_WRITER]

"Analyze the PaymentProcessor class in the bundle. Write a suite of unit tests covering: 1. Happy Path, 2. Null Inputs, 3. Network Timeouts. Use our [Test_Framework] syntax."

  

> Prompt: [EDGE_CASE_HUNTER]

"Look at the 'Validation Logic' in the bundle. Can you find a combination of inputs that would bypass these checks?"

  

> Prompt: [MOCK_DATA_GENERATOR]

"Generate a JSON file with 50 entries of mock data that matches the UserProfile schema, including 5 entries with malformed data for testing."

  

PHASE 5: DEPLOYMENT & DEVOPS

[Goal: Get it to the server.]

  

> Prompt: [CONFIG_VALIDATOR]

"Review the docker-compose.yml. Suggest specific optimizations for a production environment vs. the dev environment shown in the file."

  

> Prompt: [RELEASE_NOTE_DRAFTER]

"Compare the old bundle with the new one, and summarize the changes into a Release Note for stakeholders."

  

> Prompt: [ENV_VAR_CHECK]

"Scan the new code for any references to process.env. List all new Environment Variables that need to be added to the production server."

  

PHASE 6: MAINTENANCE & SUPPORT

[Goal: Fix bugs and keep it running.]

  

> Prompt: [STACK_TRACE_DETECTIVE]

"Here is a stack trace from production [PASTE_ERROR]. Cross-reference this with [TARGET_BUNDLE] to identify the exact line number and logic flow that caused this crash."

  

> Prompt: [REFACTOR_STRATEGIST]

"The UserAuth module is becoming too large. Suggest a strategy to split this into three smaller, decoupled micro-services."

  

> Prompt: [LEGACY_MIGRATOR]

"We are deprecating Library A in favor of Library B. Identify all files in the bundle that import Library A and show the code diff required to update them."

  

================================================================================

PART 3: PRODUCTION HARDENING PROTOCOL

================================================================================

  

PHASE 1: SEMANTIC CODE REVIEW (AUDIT)

[Goal: Identify architectural rot and complexity.]

  
PHASE 2: AUTOMATED RULE ENFORCEMENT (HARD GATES)
[Goal: Physically prevent architectural violations from merging.]

1. EXCLUSION ZONE ENFORCEMENT
   - Rule: Legacy and deprecated modules MUST NOT be imported.
   - Mechanism: The CI/CD pipeline runs `scripts/enforce_exclusion_zones.sh` before every build.
   - Fallback: The IDE is configured via `analysis_options.yaml` and `custom_lint` to throw fatal errors on banned imports locally.
   - Spike Sandbox Exception: `experimental/` and `.proto.*` files are locally whitelisted for ideation only.
   - Stabilization Gate: `lefthook.yml` must reject commits containing spike sandbox artifacts.

2. SEMANTIC CONTEXT GENERATION & AI INTEGRATION
   - Rule: Do not feed raw, bloated source code to LLMs.
   - Mechanism 1 (Legacy CLI): Developers use `scripts/generate_semantic_bundle.py` to strip comments and prevent token bloat.
   - Mechanism 2 (Modern AI-Native): Developers are officially authorized to use Cursor IDE, Windsurf, Aider, or Cline. These tools automatically handle dynamic Abstract Syntax Tree (AST) context indexing.
   - Strict Constraint: Even if using Cursor or Aider, the AI must still execute the audit-routing check first. Low-risk/low-complexity changes may self-certify; high-risk or high-complexity changes require the full "Pre-Flight Audit" (Stop-and-Think protocol) before writing code.

3. AUTOMATED CODE REVIEW ROUTING
   - Rule: Code reviews are routed based on Cyclomatic Complexity.
   - Mechanism (CI/CD): `.github/workflows/caris-hard-gates.yml` runs exclusion checks, CodeQL security analysis, and a complexity gate.
   - Mechanism (Routing Engine): `scripts/complexity_gate.py` outputs both complexity route and audit route.
     * Score < 5: Fast Model (Syntax/Formatting)
     * Score 5-20: Standard Model (Logic Verification)
     * Score > 20: Senior Architect Reasoning Model (Architecture/Security Audit)
   - High-Risk Override (Manual Stop-and-Think required regardless of score):
     * Exclusion-zone enforcement / guardrail configs
     * System constitution / governance documents
     * SQL / Prisma schema definitions and migrations
   - Low-Risk Self-Certification:
     * If Score < 5 and no high-risk paths are touched, the AI is authorized to self-certify and proceed without a human halt.
