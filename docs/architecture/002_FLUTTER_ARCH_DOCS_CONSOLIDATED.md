
ACTIVE PROFILE SELECTION
- Profile ID: 002_FLUTTER_ARCH_DOCS_CONSOLIDATED.md
- Status: Active for this template repository

================================================================================
PART 1: THE DESIGN SYSTEM ("THE UNFORGETTABLE AESTHETIC")
================================================================================

1. CORE PHILOSOPHY
   - We reject generic Material Design/Cupertino defaults.
   - We implement a "Bold" aesthetic strategy characterized by high contrast and "Exponential Typography."
   - The UI must be "Swiss/International" or "Refined/Luxury" in style.

2. TYPOGRAPHY: EXPONENTIAL SCALING
   [Constraint: Do NOT use linear font scaling.]
   - Headers: Massive scale (64px+), tight leading (0.9), distinct Display Font (e.g., DM Serif).
   - Body: Legible scale (16px), loose leading (1.5+), clean Sans-Serif (e.g., IBM Plex Sans).
   - Variable Hierarchy:
     * Display Large: 64px | Height 0.9 | Tracking -1.5 (The "Hook")
     * Display Medium: 32px | Height 1.0 | Tracking -0.5
     * Body Medium:   16px | Height 1.6 | Color: Primary @ 80% opacity
     * Label Medium:  12px | Weight 600 | Tracking 0.5 (Functional UI)

3. COLOR PALETTE
   [Constraint: No gradients. No pure Black (#000) or Pure White (#FFF).]
   - Background: Off-White (#F8F9FA) or Rich Dark.
   - Primary Text: Rich Dark (#0A0A0A).
   - Accent: One sharp, electric color (#0055FF).
   - Muted: Cool Grays (#64748B) for hierarchy.

4. WHITESPACE & LAYOUT
   - Scale: 4px, 8px, 16px, 32px, 64px.
   - Rule: "Double the padding." Let minimal components breathe.
   - Touch Targets: Minimum 44px strictly enforced via padding.

================================================================================
PART 2: APP ARCHITECTURE (MVVM)
================================================================================

1. DEPENDENCY STACK
   - Framework: Flutter
   - UI Library: Forui (Minimalist)
   - State Management: Riverpod (App-wide), flutter_hooks (Local)
   - Navigation: GoRouter (Deep linking support)
   - Typography: google_fonts
   - Horror Path Draft Persistence (Mandatory): `shared_preferences` behind a `DraftStore` interface (default profile for recoverable form drafts)

2. SEPARATION OF CONCERNS
   - VIEW (UI):
     * Strictly handle rendering and user interaction.
     * Contains NO business logic.
     * Logic-free "Presentational Components" receive data via props.
     * Connected "Container Components" watch providers.
   - VIEWMODEL (Logic):
     * Extends StateNotifier or Notifier.
     * Handles state mutations, validation, and API calls.
     * Exposes immutable state objects to the View.

3. DIRECTORY STRUCTURE
   /lib
     /core          # Theme, Config, Constants
     /features
       /auth
         /presentation
           /widgets # Presentational Components
           view.dart
           viewmodel.dart
         /data
           repository.dart
     /shared        # Reusable UI components

================================================================================
PART 3: IMPLEMENTATION REFERENCE (CODE STANDARDS)
================================================================================

/// THEME CONFIGURATION
/// Implements the "Bold" aesthetic with exponential scaling.
class AppTheme {
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _primary = Color(0xFF0A0A0A);
  static const Color _accent = Color(0xFF0055FF);
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _background,
      colorScheme: const ColorScheme.light(
        primary: _primary,
        secondary: _accent,
        surface: _background,
        onSurface: _primary,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.dmSerifDisplay(
          fontSize: 64, height: 0.9, letterSpacing: -1.5, color: _primary
        ),
        bodyMedium: GoogleFonts.ibmPlexSans(
          fontSize: 16, height: 1.5, color: _primary.withOpacity(0.8)
        ),
      ),
    );
  }
}

/// VIEWMODEL EXAMPLE
/// Strict separation of logic from UI using Riverpod.
class LoginState {
  final String email;
  final bool isLoading;
  final String? error;
  // ... copyWith & constructor
}

class LoginViewModel extends StateNotifier<LoginState> {
  LoginViewModel() : super(LoginState());
  
  Future<void> login() async {
    state = state.copyWith(isLoading: true);
    // Execute logic...
  }
}

================================================================================
PART 4: DATA LAYER & PERFORMANCE PROTOCOLS
================================================================================

1. PAGINATION STRATEGY (The "Keyset Pivot")
   - VIOLATION: Using `OFFSET 1000 LIMIT 20`. This causes O(N) linear scans.
   - REQUIREMENT: Use Keyset/Cursor Pagination.
   - PATTERN: `WHERE id > last_seen_id ORDER BY id LIMIT 20`.
   - PERFORMANCE: Ensures O(log N) access via B-Tree Index regardless of depth.

2. LIST RENDERING
   - VIOLATION: Standard Column or ListView for large datasets.
   - REQUIREMENT: Use `ListView.builder` or `SuperList`.
   - CONSTRAINT: Implement "Lazy Loading" to prevent memory bottlenecks.

3. SQL OPTIMIZATION (Backend Support)
   - DIAGNOSTIC: Run `EXPLAIN (ANALYZE, BUFFERS)` on all slow queries.
   - ANTI-PATTERN: `Seq Scan` (Sequential Scan) on large tables.
   - INDEXING RULES:
     * B-Tree: For standard comparisons (=, >, <).
     * GIN: MANDATORY for JSONB, Arrays, and Full-Text Search.
     * Trigram (pg_trgm): MANDATORY for wildcard searches (`LIKE '%term'`).

================================================================================
PART 5: PRODUCTION HARDENING & QA
================================================================================

1. THE "IRON LAW" OF TDD
   - Rule: "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST."
   - Cycle:
     1. RED: Write a test that fails (confirms the need).
     2. GREEN: Write simple code to pass the test.
     3. REFACTOR: Clean up without changing behavior.

2. THE "HORROR PATH" PROTOCOL
   - Do not just test success. You must explicitly test and handle:
     1. Mid-Transaction Failure (DB connection drops).
     2. Upstream Collapse (API returns 500).
     3. Resource Exhaustion (Disk full / Memory limits).
   - Active Recovery Requirement:
     * Wrap remote calls with retry/backoff where safe (do not retry non-idempotent writes blindly).
     * Surface recoverable failures as user-facing retry states, not silent failures.
   - State Restoration Requirement (Prescriptive):
     * ViewModels must persist recoverable draft input via a `DraftStore` abstraction backed by `shared_preferences` BEFORE network mutation.
     * Required command flow: `saveDraft(draft)` -> attempt mutation -> `clearDraft(key)` on success -> `restoreDraft(key)` on failure/app restart.
     * Forbidden in draft store: passwords, auth tokens, payment card data, and secrets.
     * If draft payloads exceed `shared_preferences` suitability (large blobs/attachments), escalate for explicit architecture sign-off; do not introduce ad-hoc storage libraries.
   - Requirement: User-friendly error states, no raw stack traces exposed in UI.

3. ACCESSIBILITY CHECKLIST
   - Touch Targets: Are all interactive elements at least 44x44px?
   - Input Errors: Do not rely on color alone. Use explicit text descriptions.
   - Contrast: Verify "Off-white" background maintains ratio with "Rich Dark" text.

4. FINAL REVIEW GATES
   - [ ] Does typography follow the 64px/16px exponential scale?
   - [ ] Is business logic fully decoupled from FScaffold/FCard?
   - [ ] Are we using Keyset pagination instead of Offset?
   - [ ] Have we verified the "Horror Path" for network/data failures?
   - [ ] Does the ViewModel use the mandated `DraftStore` (`shared_preferences`) flow for recoverable input before mutation?

5. IDE ARCHITECTURE GUARDRAILS
   - REQUIREMENT: All developers must run `flutter pub add dev:custom_lint`.
   - ENFORCEMENT: The `analysis_options.yaml` is configured to throw IDE-level errors if a developer attempts to import from an Exclusion Zone (e.g., `legacy_api_folder`).
   - ENFORCEMENT: `custom_lint` must also throw fatal errors for raw color literals and off-scale `fontSize` values outside the locked token scale (for example 12/16/32/64 in the active profile).
   - RULE: Never use `// ignore: ban_legacy_imports` to bypass this constraint.
```
