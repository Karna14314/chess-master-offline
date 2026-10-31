# ChessMaster Offline — Stability & Performance Report

## Overview
This report evaluates the app's stability, ANR prevention, memory management, and rendering performance following the UI redesign and asset bundling updates.

## 1. Asset & Font Bundling Stability
- **Inter Font Assets**: Bundled four standard weights (400 Regular, 500 Medium, 600 SemiBold, 700 Bold) in `assets/fonts/` under the SIL Open Font License 1.1.
- **Runtime Fetching Eliminated**: Fully removed `google_fonts` package dependency from `pubspec.yaml` and source code. Zero network calls or external font downloading occurs, ensuring 100% offline stability.
- **Typography Inheritance**: App-wide typography is centralized in `ThemeData.fontFamily = 'Inter'`. Widgets inherit text styling directly from `ThemeData.textTheme`, eliminating layout calculation discrepancies.

## 2. Cold-Start & ANR Prevention
- **Async Deferred Startup**: Heavy services (Diagnostics, Local Notifications, Lesson curriculum, Opening Playbook) are deferred to a post-frame microtask (`WidgetsBinding.instance.addPostFrameCallback`), ensuring initial window rendering is never blocked.
- **Async Asset Loading in UI**: `LessonsScreen` and `OpeningPlaybookScreen` utilize `FutureBuilder` to cleanly handle asynchronous asset loading with loading spinners and retry mechanisms, preventing cold-open blank screens on mobile devices.
- **Stockfish Serialization**: All native Stockfish engine commands are routed serially through `_EngineExecutionQueue.run(...)` and `_stopCurrentSearchAndWait` sends `stop` followed by `isready` and awaits `bestmove` / `readyok` to prevent native thread contention and SIGSEGV crashes.

## 3. Memory & Cache Management
- **Image Cache Bounds**: Configured `PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024` (30 MB limit) and `maximumSize = 100` images to prevent OutOfMemory crashes during long play sessions.
- **SVG Byte Caching**: Piece SVG assets are preloaded via `PieceAssets.preloadAssets` with `CustomPainter` repaint boundary optimizations.

## 4. UI Overflow & Layout Safety
- **Pass & Play Subtitle**: Shortened from "Two players, 1 phone" to "Same device" to eliminate text truncation on narrow viewports.
- **Flexible Row Widgets**: Navigation bars and player info headers employ `Expanded` and `FittedBox` wrappers with `TextOverflow.ellipsis`.
- **Flat Surface Cards**: Cards are styled with flat surface tokens (`#302E2B` dark, `#FFFFFF` light) and 16pt border radii without heavy drop shadows or coloured borders.

## 5. Verification Checklist
- [x] Zero compilation/analysis errors in `flutter analyze`.
- [x] Zero network calls for typography or chess data.
- [x] All native Stockfish commands serialized.
- [x] Clean loading, empty, and error states for curriculum and openings.
