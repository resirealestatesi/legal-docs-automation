# AGENTS.md — LegalDocs Automation

## Project Overview
Flutter multiplatform app (Windows/Mac/iOS/Android) for Legal Consulting Center.
Automates .docx documents via text highlighting. Offline-first with Supabase sync.

## Build & Run Commands

```bash
# Install dependencies
flutter pub get

# Run on Windows
flutter run -d windows --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx

# Run on Chrome (web)
flutter run -d chrome --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx

# Run on all connected devices
flutter run -d all

# Build release
flutter build windows
flutter build apk
```

## Lint & Analyze

```bash
# Full analysis
flutter analyze

# Analyze single file
dart analyze lib/presentation/screens/highlighter/document_highlighter_screen.dart

# Auto-fix lint issues
dart fix --apply
```

## Testing

```bash
# Run all tests
flutter test

# Run single test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

## Architecture (Clean Architecture)

```
lib/
├── config/          → Theme, colors, constants, Supabase config
├── core/            → Errors (failures.dart, exceptions.dart), network, utils
├── data/            → Datasources (local/, remote/), models, repository impls
├── domain/          → Entities, repository interfaces, use cases
├── presentation/    → Screens, widgets, providers (Riverpod)
├── services/        → Sync service, docx service
└── app.dart, app_router.dart, main.dart
```

## Code Style Guidelines

### Imports
- Use **relative imports** within the project: `import '../../config/theme/app_colors.dart';`
- Order: 1) dart, 2) flutter, 3) packages, 4) relative project imports
- No unused imports — remove immediately

### Naming
- **Files**: `snake_case.dart` (e.g., `company_access_screen.dart`)
- **Classes**: `PascalCase` (e.g., `CompanyAccessScreen`)
- **Variables/methods**: `camelCase` (e.g., `_loadDocument`)
- **Private**: prefix with `_` (e.g., `_isLoading`)
- **Constants**: `camelCase` for static const (e.g., `AppColors.primary`)

### Types
- Always use explicit types on public APIs
- `var`/`final` allowed for local variables with obvious types
- Use `const` constructors where possible (`prefer_const_constructors`)

### Widgets
- Use `ConsumerWidget` or `ConsumerStatefulWidget` for Riverpod
- Extract reusable widgets to `lib/presentation/widgets/`
- `const` constructors on all stateless widgets

### Error Handling
- Use custom `Failure` classes from `lib/core/errors/failures.dart`
- Wrap remote calls in try/catch, return `Either<Failure, T>` or throw
- Show errors via `SnackBar` or `ErrorDialog` widget

### State Management (Riverpod)
- Providers in `lib/presentation/providers/`
- Use `AsyncNotifierProvider` for async state
- Use `Provider` for synchronous dependencies
- Use `FutureProvider.family` for parameterized async data

### Formatting
- Single quotes for strings
- Trailing commas on multi-line widget trees
- 80 char line limit (soft)
- `sort_child_properties_last: true`

## Supabase Schema
Tables: `companies`, `templates`, `automations`
RLS enabled with permissive read/insert policies.
Run `supabase/migrations/001_initial_schema.sql` to create.

## Key Packages
| Package | Purpose |
|---------|---------|
| `flutter_riverpod` 3.x | State management (Notifier pattern) |
| `go_router` 17.x | Declarative routing |
| `supabase_flutter` | Remote database sync |
| `docx_creator` | .docx reading with highlighting |
| `shared_preferences` | Local persistence (company code) |
| `file_picker` | .docx file selection |
