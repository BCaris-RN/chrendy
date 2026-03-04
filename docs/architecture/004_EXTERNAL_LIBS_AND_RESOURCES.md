
\================================================================================

WHITELIST AUTHORITY

\================================================================================

Rule: Dependencies in this document are pre-vetted and approved for use.
Constraint: Any package NOT listed here requires explicit, documented sign-off before installation.

\================================================================================

PART 0: CROSS-STACK MANDATORY WHITELISTS (RESILIENCE + DESIGN TOKENS)

\================================================================================

### RESILIENCE PATTERN LIBRARIES (MANDATORY FOR REMOTE CALLS)

* **Rule:** Any call to an external dependency (HTTP API, DB proxy, queue, or third-party SDK) must be wrapped in a standardized resilience policy using Circuit Breakers and/or Exponential Backoff.
* **Java / Kotlin:** **Resilience4j** [resilience4j.readme.io](https://resilience4j.readme.io/) - Mandated for circuit breakers, retries, bulkheads, and rate limiting.
* **.NET / C#:** **Polly** [github.com/App-vNext/Polly](https://github.com/App-vNext/Polly) - Mandated resilience strategy library for retries, circuit breakers, and fallback policies.
* **JavaScript / TypeScript:** **p-retry** [github.com/sindresorhus/p-retry](https://github.com/sindresorhus/p-retry) - Approved retry library for backoff wrappers around `fetch`/HTTP clients.
* **Dart / Flutter:** **Http (`package:http`) + repository-owned retry wrapper** - Approved baseline. The stack mandates a local wrapper (e.g., `retry_policy.dart`) implementing backoff/circuit-breaker behavior around remote calls.
* **Implementation Constraint:** "Graceful failure" alone is insufficient. The generated code must demonstrate active recovery (retry/circuit breaker) and safe stop conditions.
* **State Restoration Rule:** View models / client state layers must persist user input locally before mutation requests so failed submissions recover to the pre-submit state.
* **Approved Draft Persistence (Flutter Profile):** **shared_preferences** via a `DraftStore` adapter for recoverable non-secret form drafts. Do not invent ad-hoc temp files or random local caches.
* **Approved Draft Persistence (Next.js/React Profile):** **IndexedDB via `idb`** for recoverable client-side drafts. `localStorage` is restricted to trivial preferences (theme, dismissed UI flags).
* **Security Constraint (All Profiles):** Passwords, auth tokens, payment card data, and secrets are forbidden in client/local draft stores unless a separately approved secure-storage profile is documented.

### DESIGN TEXTURE ASSET LIBRARY (ANTI-SLOP WHITELIST)

* **Rule:** Atmospheric depth must use whitelisted texture assets instead of ad-hoc generated CSS noise when an approved asset exists.
* **Required Project Path:** `assets/textures/` (or framework equivalent static asset directory).
* **Whitelisted Texture IDs / Filenames (baseline pack):**
  * `grain_soft_01.png`
  * `grain_heavy_01.png`
  * `noise_film_01.png`
  * `paper_fiber_01.png`
  * `mesh_shadow_01.png`
* **Usage Constraint:** AI-generated UI code must reference these IDs/filenames via design tokens/config and may not invent new texture names without documented approval.

\================================================================================

PART 1: FLUTTER ECOSYSTEM RESOURCES

\================================================================================

  

### OFFICIAL & EDUCATIONAL

* **Flutter Website:** [flutter.dev](https://flutter.dev/) - Google’s UI toolkit for building natively compiled applications.
* **Official Gallery:** [github.com/flutter/gallery](https://github.com/flutter/gallery) - Demo for Material Design widgets.
* **Roadmap.sh:** [roadmap.sh/flutter](https://roadmap.sh/flutter) - Community-curated learning roadmap.
* **Flutter Youtube:** [youtube.com/flutterdev](https://www.youtube.com/flutterdev) - Official channel including "The Boring Show".

  

### UI FRAMEWORKS & COMPONENT LIBRARIES

* **Forui:** [github.com/forus-labs/forui](https://github.com/forus-labs/forui) - Minimalistic UI library inspired by shadcn/ui.
* **Shadcn Flutter:** [github.com/nank1ro/flutter-shadcn-ui](https://github.com/nank1ro/flutter-shadcn-ui) - Port of shadcn/ui.
* **GetWidget:** [github.com/getwidget/getwidget](https://github.com/getwidget/getwidget) - Open source UI library.
* **TDesign:** [github.com/Tencent/tdesign-flutter](https://github.com/Tencent/tdesign-flutter) - Enterprise design system by Tencent.
* **Flutter Neumorphic:** [github.com/Idean/Flutter-Neumorphic](https://github.com/Idean/Flutter-Neumorphic) - Neumorphic UI kit.

  

### STATE MANAGEMENT

* **Bloc:** [github.com/felangel/bloc](https://github.com/felangel/bloc) - Predictable state management library.
* **Riverpod:** [github.com/rrousselGit/river_pod](https://github.com/rrousselGit/river_pod) - Compile-safe reimplementation of Provider.
* **Provider:** [github.com/rrousselGit/provider](https://github.com/rrousselGit/provider) - Wrapper around InheritedWidget.
* **GetX:** [github.com/jonataslaw/getx](https://github.com/jonataslaw/getx) - Extra-light, reactive state management.
* **MobX:** [github.com/mobxjs/mobx.dart](https://github.com/mobxjs/mobx.dart) - TFRP state management.
* **Signals:** [github.com/rodydavis/signals.dart](https://github.com/rodydavis/signals.dart) - Reactive programming signal pattern.

  

### NAVIGATION & ROUTING

* **GoRouter:** [github.com/csells/go_router](https://github.com/csells/go_router) - Declarative routing package.
* **AutoRoute:** [github.com/Milad-Akarie/auto_route_library](https://github.com/Milad-Akarie/auto_route_library) - Code generation for routing.
* **Beamer:** [github.com/slovnicki/beamer](https://github.com/slovnicki/beamer) - Navigator 2.0 implementation.

  

### ANIMATION & EFFECTS

* **Lottie:** [github.com/xvrh/lottie-flutter](https://github.com/xvrh/lottie-flutter) - Render After Effects animations.
* **Flutter Animate:** [pub.dev/packages/flutter_animate](https://pub.dev/packages/flutter_animate) - Performant animation effects library.
* **Rive:** [github.com/rive-app/rive-flutter](https://github.com/rive-app/rive-flutter) - Interactive vector animations.
* **Shimmer:** [github.com/hnvn/flutter_shimmer](https://github.com/hnvn/flutter_shimmer) - Loading effect.

  

### UTILITIES & TOOLS

* **Flutter Launcher Icons:** [github.com/franzsilva/flutter_launcher_icons](https://github.com/franzsilva/flutter_launcher_icons) - Icon generator.
* **FVM (Flutter Version Management):** [github.com/leoafarias/fvm](https://github.com/leoafarias/fvm) - Manage multiple Flutter SDK versions.
* **Melos:** [github.com/invertase/melos](https://github.com/invertase/melos) - Monorepo management tool.
* **Very Good CLI:** [github.com/VeryGoodOpenSource/very_good_cli](https://github.com/VeryGoodOpenSource/very_good_cli) - Project scaffolding tool.

  
### WEB & CROSS-PLATFORM MODERN UPDATES

* **[MODERN UPDATE] Expo:** (External Knowledge) The mandated industry standard for React Native, allowing shared Next.js/Zustand logic for high-velocity cross-platform mobile development.
* **[MODERN UPDATE] Remix / Astro:** (External Knowledge) Approved Next.js alternatives. Remix is approved for strict Web Fetch API standards (Horror Path compliance), and Astro is mandated for zero-JS hydration content sites.

  

\================================================================================

PART 2: CORE DART PACKAGES (METADATA)

\================================================================================

  

### CORE INFRASTRUCTURE

* **Analyzer:** [pub.dev/packages/analyzer](https://pub.dev/packages/analyzer)
    * **Description:** Static analysis of Dart code. Foundational for IDEs and linters.
    * **Docs:** [github.com/dart-lang/sdk/tree/main/pkg/analyzer](https://github.com/dart-lang/sdk/tree/main/pkg/analyzer)
* **Http:** [pub.dev/packages/http](https://pub.dev/packages/http)
    * **Description:** Composable, multi-platform, Future-based API for HTTP requests.
    * **Repo:** [github.com/dart-lang/http](https://github.com/dart-lang/http)
* **Built Value:** [pub.dev/packages/built_value](https://pub.dev/packages/built_value)
    * **Description:** Immutable value types, Enum classes, and JSON serialization.
    * **Repo:** [github.com/google/built_value.dart](https://github.com/google/built_value.dart)

  

### DATA & PARSING

* **UUID:** [pub.dev/packages/uuid](https://pub.dev/packages/uuid)
    * **Description:** RFC4122 (v1, v4, v5, v6, v7, v8) UUID Generator.
* **Archive:** [pub.dev/packages/archive](https://pub.dev/packages/archive)
    * **Description:** Encoders/decoders for zip, tar, gzip, etc.
* **PetitParser:** [pub.dev/packages/petitparser](https://pub.dev/packages/petitparser)
    * **Description:** Dynamic parser framework for efficient grammars.
* **Args:** [pub.dev/packages/args](https://pub.dev/packages/args)
    * **Description:** Parser for command-line arguments.

  

### TESTING

* **Test API:** [pub.dev/packages/test_api](https://pub.dev/packages/test_api)
    * **Description:** Core API for Dart tests and expectations.
* **Patrol:** [pub.dev/packages/patrol](https://pub.dev/packages/patrol)
    * **Description:** Powerful UI testing framework (overcomes flutter_driver limits).
* **[MODERN UPDATE] Playwright:** (External Knowledge)
    * **Description:** The mandated web E2E equivalent to Patrol. Must be used to execute the "Horror Path" protocol for Next.js/React environments, simulating network collapses, injecting malicious payloads, and verifying retry/state-restoration behavior.

  

\================================================================================

PART 3: DEVELOPER TOOLS & SERVICES

\================================================================================

  

### NETWORKING & TUNNELING

* **Ngrok:** [ngrok.com](https://ngrok.com)
    * **Function:** Secure introspectable tunnels to localhost.
    * **Usage:** `ngrok http 8080` exposes local port 8080 to the public internet via secure tunnel.
    * **Setup:** Install -> Auth (add token) -> Run.

  

### BACKEND AS A SERVICE (BaaS)

* **Firebase:** [firebase.google.com](https://firebase.google.com) - Auth, Database, Storage, Analytics.
* **Supabase:** [supabase.com](https://supabase.com) - Open source Firebase alternative (Postgres).
* **Appwrite:** [appwrite.io](https://appwrite.io) - Secure backend server for Web, Mobile & Flutter.
* **Serverpod:** [serverpod.dev](https://serverpod.dev) - Backend written in Dart.
* **[MODERN UPDATE] Convex:** (External Knowledge) Approved highly-optimized BaaS for React/Next.js, replacing Prisma/Supabase for purely TypeScript environments.
* **[MODERN UPDATE] Clerk / Better Auth:** (External Knowledge) Mandated modern standalone auth providers ensuring accessible UI and edge-runtime compliance.
* **[MODERN UPDATE] PocketBase:** (External Knowledge) Approved single-file Go backend with embedded SQLite for maximum solo-developer velocity.

  

### OPEN SOURCE APPS (REFERENCE)

* **AppFlowy:** [github.com/AppFlowy-IO/appflowy](https://github.com/AppFlowy-IO/appflowy) - Notion alternative (Flutter + Rust).
* **RustDesk:** [github.com/rustdesk/rustdesk](https://github.com/rustdesk/rustdesk) - Remote desktop software (Flutter + Rust).
* **Spotube:** [github.com/KRTirtho/spotube](https://github.com/KRTirtho/spotube) - Spotify client.
* **History of Everything:** [github.com/2d-inc/HistoryOfEverything](https://github.com/2d-inc/HistoryOfEverything) - Vertical timeline animation demo.
```
