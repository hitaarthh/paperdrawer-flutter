# PaperDrawer iOS app: architecture and contracts

Design source: `design/mobile-system/` (tokens, components, screens, platforms).
Pattern: the official Flutter layered architecture (`.claude/skills/flutter-apply-architecture-best-practices`):
**data** (services + repositories, single source of truth) → **domain** (immutable models, pure logic) → **ui** (MVVM: ChangeNotifier view models + lean views). Dependency injection with `provider`. Navigation with `go_router` (`StatefulShellRoute` for tabs).

Imports: use `package:material_ui/material_ui.dart` and `package:cupertino_ui/cupertino_ui.dart` (the `flutter/material.dart` and `flutter/cupertino.dart` libraries are deprecated in Flutter 3.50). Icons: custom `PdGlyph` for tab/scan icons, `package:lucide_icons_flutter/lucide_icons.dart` (`LucideIcons.x`) for everything else, `CupertinoIcons.share` for share and the drawn `PdGlyph.back` for pushed screens.

Region: India first (₹, Indian grouping, 1915 / IRDAI ladders). All money is minor units + currency code.

## Shared account build

When `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are configured, `main.dart`
opens `SharedBootstrap`. `SharedAccount` uses the same Supabase Auth backend as
the web app. iOS session data is stored in the app's Keychain. Signup verification
uses the existing web callback and password reset uses the web sign-in flow.
`SharedSession` resets the in-memory vault on account changes.

`SharedVaultService` reads bills, bill parts, documents, originals and account
settings with the current user's session and owner RLS. The shared router gates
`/home`, `/vault`, `/settings` and the Add routes behind the account.
Add opens the manual Files form. Save writes through the existing `save_bill` or
`save_document` RPC with one original in the owner's private storage.
Bills require a purchase date and documents require an end date. The form uses
USD to match the shared drawer. Each form keeps its item ID on retry.
A confirmed save adds the item to the shared snapshot and opens its detail.
Shared item edits open the web form. Account settings save email reminder
timing (30, 7 or 2 days) and delivery preferences to the owner's `profiles` row.
The shared build clears pending claim notifications left by earlier versions at launch.
Shared vault exports and account deletion open the existing web flows. Originals are downloaded
into the temporary directory as needed. The shared build does not open the
SQLite database or transfer existing device-only originals. The unconfigured
build uses the on-device repositories and routes below.

## Folder layout

Both entry points use `ui/features/intro/app_opening.dart` to play the opening
artwork while their startup future runs. On iOS, the first Flutter frame aligns
with the centered mark in the system launch storyboard. On each cold launch,
the reveal plays for 1.5 seconds and holds the final frame for at least 350 ms
before fading into the resolved route. Reduced Motion shows the static artwork
while loading and opens the route as soon as it is ready. Startup errors take
precedence over the animation, and retrying does not replay it.

```
lib/
  main.dart                     bootstrap: open db, repositories, services → runApp
  app.dart                      PaperDrawerApp: providers + MaterialApp.router + theme
  routing/router.dart           GoRouter config and route paths
  domain/
    formats.dart                civil dates, ₹ money, mono/long/short dates
    item_status.dart            CoverWindow, ItemSummary, statuses, filters, limits
    ladders.dart                claim escalation ladders
    bill_reader.dart            OCR lines → ScanReading
    claim_message.dart          drafted message for a claim step
    models/item.dart            ItemKind, ItemDraft, Item, Attachment, PendingFile
    models/claim.dart           Claim, ClaimEvent, ClaimType, ClaimWant, ClaimStatus
  data/
    services/app_database.dart  sqflite open + migrations (v1–v6)
    services/file_store.dart    private originals storage
    services/text_recognizer.dart  Vision OCR via method channel
    services/reminder_scheduler.dart  local notifications planning + scheduling
    services/device_storage.dart    iOS exclude-from-backup channel
    services/exporter.dart      export-everything zip, claim kit
    services/today.dart         Today clock (ChangeNotifier)
    repositories/item_repository.dart
    repositories/claim_repository.dart
    repositories/settings_repository.dart
  ui/
    core/theme/tokens.dart      Pd.* colours, spacing, radii, shadows
    core/theme/type.dart        PdType.* text styles, isLargeText()
    core/theme/app_theme.dart   pdTheme(), pdCupertinoTheme()
    core/widgets/*.dart         the design-system components (below)
    features/shell/             AppShell (tab bar host)
    features/vault/             VaultViewModel, VaultScreen
    features/add/               AddFlow, CameraScreen, ReadingScreen, ItemFormViewModel, ItemFormScreen
    features/item/              ItemDetailScreen (+ view model), AttachmentViewer
    features/claims/            Legacy screens retained as source, outside the Phase 1 navigation
    features/settings/          SettingsScreen, SharedSettingsScreen, ArchiveScreen
```

## Data contracts

All repositories extend `ChangeNotifier`, hold an in-memory snapshot loaded at
startup, write through to SQLite, serialize writes through one queue, and call
`notifyListeners()` after every successful write. Errors propagate as
exceptions; `FormatException.message` is always user-facing copy.

### `AppDatabase` (`data/services/app_database.dart`)
`static Future<Database> open(String path, {DatabaseFactory? factory})`.
Schema v6, `PRAGMA foreign_keys = ON`:
- `items(id TEXT PK, kind TEXT, name TEXT, source TEXT, subtype TEXT, reference TEXT, serial_number TEXT, notes TEXT, amount_minor INTEGER, currency TEXT, starts_on TEXT, return_until TEXT, cover_until TEXT, component_warranty_until TEXT, component_warranty_name TEXT, remind INTEGER, reminder_at INTEGER, coverage_renews INTEGER, created_at INTEGER, updated_at INTEGER, archived_at INTEGER)`
- `attachments(id TEXT PK, item_id TEXT REFERENCES items(id) ON DELETE CASCADE, rel_path TEXT, name TEXT, bytes INTEGER, position INTEGER, created_at INTEGER)`
- `claims(id TEXT PK, item_id TEXT REFERENCES items(id) ON DELETE SET NULL, item_label TEXT, type TEXT, want TEXT, problem TEXT, reference TEXT, opened_on TEXT, noticed_on TEXT, step INTEGER, step_since TEXT, last_heard_on TEXT, settled_on TEXT, nudge_days INTEGER, follow_up_at INTEGER)`
- `claim_events(id TEXT PK, claim_id TEXT REFERENCES claims(id) ON DELETE CASCADE, on_date TEXT, kind TEXT, text TEXT, reference TEXT, created_at INTEGER)`
- `claim_event_photos(event_id TEXT PK REFERENCES claim_events(id) ON DELETE CASCADE, rel_path TEXT, name TEXT, bytes INTEGER)`
- `preferences(key TEXT PK, value TEXT)`

Dates are `yyyy-mm-dd` (`isoDate` / `parseIsoDate`). Migration from v1 keeps
every record: `records` → `items` (receipt→bill, policy→policy, document→agreement;
`recorded_on`→`starts_on`; `deadline`→`cover_until`; `amount_cents`→`amount_minor`
with currency `USD`; `archived_at` kept), each `attachment_key` → one
`attachments` row; the old table is renamed `records_v1_backup`, never dropped.
Version 3 adds an optional serial number. Version 4 adds the ledger’s follow-up instant, entry reference and photo table while retaining earlier events. Version 5 adds an optional component warranty date and name. Version 6 adds an optional reminder instant in UTC epoch milliseconds and an optional renewal flag. Null fields keep the established reminder lead time and date labels.

### `FileStore` (`data/services/file_store.dart`)
`FileStore(Directory root)`; `Future<Attachment> import(String itemId, PendingFile file, {bool claimPhoto = false})`
copies into `root/attachments/<itemId>-<uuid><ext>`; accepts `.pdf .jpg .jpeg .png .heic .heif .webp`, 1 byte–20 MB, else `FormatException('Choose a photo or PDF up to 20 MB.')`.
Claim photos accept the same image types and live in `root/claim-photos/`.
`String absolute(String relPath)`, `String relative(String absPath)`, `Future<void> remove(String absPath)` (ignores missing), `Future<void> removeAll()`.

### `ItemRepository`
- `ItemRepository(Database db, FileStore files)`, `Future<void> load()`
- `List<Item> get items` (all, newest first), `List<Item> get active`, `List<Item> get archived`, `Item? byId(String id)`, `int get activeCount`, `bool get atLimit` (`activeCount >= baseItemLimit`)
- `Future<Item> create(ItemDraft draft, {List<PendingFile> files = const []})` — throws `LimitReachedException` at the limit, `FormatException('Add a name so you can find it later.')` for a blank name. Copies files first; on DB failure removes the copies.
- `Future<Item> update(String id, ItemDraft draft, {List<PendingFile> addFiles = const [], Set<String> removeAttachmentIds = const {}})`
- `Future<void> setArchived(String id, bool archived)` (restoring checks the limit)
- `Future<void> delete(String id)` — removes its files; claims keep `item_label`
- `Future<void> eraseAll()`

### `ClaimRepository`
- `ClaimRepository(Database db, FileStore files)`, `Future<void> load()`
- `List<Claim> get claims` (open first, oldest wait first; then settled, newest first), `Claim? byId(String id)`, `Claim? openFor(String itemId)`, `bool hasOpenClaim(String itemId)`, `int needsAction(DateTime today)` (open claims with status escalate)
- `openLedger(Item item, DateTime today)` returns the existing open ledger or creates one with an opening event in a single transaction.
- `addEntry(String id, LedgerDraft entry, DateTime now)` adds a dated call, email, visit, note or refund, with an optional reference and photo. A supplied follow-up and the event commit together. A failed write cleans up the copied photo.
- `setFollowUp(String id, DateTime? followUp, DateTime now)` schedules or clears an explicit follow-up. Settling clears the active follow-up.
- `Future<Claim> start({required String itemId, required String itemLabel, required ClaimType type, required ClaimWant want, required String problem, String reference = '', DateTime? noticedOn, required DateTime today})` — step 0, logs an `opened` event; `nudgeDays` from `ladderFor(type)[0].waitDays`
- `Future<void> logSent(String id, DateTime today, {int? step})` records the sent message and resets the waiting clock. It defaults to the current step. When `step` is the currently recommended next step, it advances the claim and records the send in the same transaction.
- `Future<void> logReply(String id, DateTime today, {String note = ''})` — sets `lastHeardOn`
- `Future<void> advance(String id, DateTime today)` — step+1 (max 3), `stepSince = today`, nudgeDays from the new rung
- `Future<void> addNote(String id, DateTime today, String text)`
- `Future<void> settle(String id, DateTime today, {String note = ''})`, `Future<void> reopen(String id, DateTime today)`
- `Future<void> delete(String id)`, `Future<void> eraseAll()`

### `SettingsRepository`
- `SettingsRepository(Database db)`, `Future<void> load()`
- `bool remindersOn` (default false until the user turns them on and grants permission), `int leadDays` (default 7; choices 1, 3, 7, 14, 30), `String? ticketDismissedKey`
- `Future<void> setRemindersOn(bool)`, `setLeadDays(int)`, `dismissTicket(String key)`, `eraseAll()`

### `Today` (`data/services/today.dart`)
`class Today extends ChangeNotifier { Today([DateTime Function()? now]); DateTime get value; DateTime get instant; void refresh(); }` provides a civil date and a current instant. The shell refreshes the civil date on resume.

### Services
- `TextRecognizer` (abstract): `Future<List<String>> recognize(String path)`; `PlatformTextRecognizer` uses MethodChannel `app.paperdrawer.mobile/text`, method `recognize`, args `{'path': String}` → `List<String>` lines (Apple Vision; PDFs: first 3 pages via PDFKit). Never throws: returns `[]` on failure.
- `CaptureService.inspect(PendingFile)` reads the original's size and provides preview bytes for a supported image. `pickLedgerPhoto()` picks one image from the device photo library. The camera session supports capture and torch control.
- `ScanReading readBill(List<String> lines, {required DateTime today, String currency = 'INR'})` in `domain/bill_reader.dart` provides optional kind, name, source, reference, serial number, amount, start and end dates, and separate comprehensive and component warranty durations. The amount is read in the requested currency. `ScanReading.read` identifies populated fields.
- `ReminderScheduler` observes items and reminder preferences and schedules device notifications with `planReminders({items, leadDays, now})`. It clears old pending notifications before rescheduling. Each new payload opens `/vault/item/<id>`. The planner retains an optional legacy claim argument for regression coverage.
- `Exporter`: `Future<File> exportEverything({required List<Item> items, required List<Claim> claims})` → zip (`paperdrawer-export-<yyyy-mm-dd>.zip` with `paperdrawer.json`, `originals/` and any `claim-photos/`); `Future<List<XFile>> claimKit(Item item, {Claim? claim})` → originals + `<name>-claim-kit.txt` summary.
- `buildLedgerPdf` generates an on-device PDF with the entries, references, serial number and names of the files on record. Originals remain available through the claim kit and attachment controls.

## Routes (`routing/router.dart`)

The app opens on `/home`. Home shows the nearest date per item within 14 days, with a scheduled reminder as a fallback for files without an upcoming deadline. The Drawer branch retains the `/vault` location and its `filter=due`, `review=old`, and `added=<id>` destinations. The bell on Home and Drawer opens `/notifications`, which shows upcoming device reminders for on-device items. The signed-in build explains how to manage account email reminders. Item details and Settings subpages cover the dock.

`PdPage` uses live 250 ms Cupertino transitions. The pushed page moves over the stationary page below it. Back navigation reveals the existing list at its previous scroll position.

Add opens the manual, Files-first form at `/add`. Local `/edit/:id` uses the same form. The four supported types are Bill, Policy, Vehicle papers, and Agreement. A file-specific notification date and time overrides the automatic lead time for that item. The signed-in build uses its existing server contract, account email reminders, and web editor. Settings opens with an Account card and navigation rows for Plan, Reminders & notifications, Your data, and Legal. Account, Plan, and Your data have their own Settings routes at `/settings/account`, `/settings/plan`, and `/settings/data`. Notices and legal documents are available under `/settings/notifications` and `/settings/legal`. Local Archive is linked from Your data. Legal opens the canonical `www.paperdrawer.app` pages.

Old claim links redirect to Home in both builds. Phase 1 leaves saved legacy claim records intact and retains them in complete backups. The older camera, reading, and review screens remain reachable at `/add/camera`, `/add/reading`, and `/add/details`. `CaptureReadingArgs` carries the originals and chosen kind. `AddDetailsArgs.effectiveKind` uses that choice first, then the recognized kind, then Bill. Both routers use `buildAddRoutes`.

## UI kit (`ui/core/widgets/`)

- `icons.dart`: `enum PdGlyph { vault, settings, scan, back, home, add }`; `PdIcon(PdGlyph, {double size = 24, Color color = Pd.text})`; `PaperDrawerMark({double size = 28})`.
- `brand_bar.dart`: `PdBrandBar({Widget? trailing, VoidCallback? onMarkTap})`: the iOS top bar with `PaperDrawerMark(size: 21)` + "PaperDrawer" wordmark (`PdType.wordmark`), adds the top safe-area inset, 44 tall, screen-margin sides; with `onMarkTap` it is a button (`ValueKey('brand-mark')`), otherwise a header. `PdBrandAction({required String label, required VoidCallback? onPressed, IconData? icon})`: compact lime trailing action (44 tall, radius-sm, 18pt icon, 15/600 label, lime-pressed on press).
- `button.dart` provides `PdButton.primary`, `.secondary`, `.destructive`, `.onPaper` and `.text`. Each takes `label`, `onPressed`, `icon`, `expand`, `busy` and `key`. Primary uses lime, body-strong type and a 52-point minimum height. Secondary, destructive and on-paper buttons use uppercase mono labels. Destructive uses a signal outline and label. Text uses lime body-strong type and supports `monospaced: true` for uppercase mono labels. All have a 48-point minimum tap target.
- `chips.dart`: `PdFilterChip({label, int? count, selected, onTap})`, `PdChoiceChip({label, selected, onTap, bool onPaper = true})`, `PdChipRow({children})` (horizontal scroll, screen-margin edge padding).
- `filter_tabs.dart`: `PdFilterTabs({required List<PdFilterTab> children})` is a horizontally scrolling row of underlined filters used in Vault and Claims. Each filter supplies its label, count, selected state and tap action.
- `stamp.dart`: `PdStamp(StampKind kind, {double angleDegrees = -12, bool land = false, VoidCallback? onLanded, String? compactLabel})` — excluded from semantics; land = 120ms 1.15→1 scale + `HapticFeedback.lightImpact()`; on-dark kinds (waiting/escalate/settled) are drawn upright with dark colours. `compactLabel` supplies the shorter wording and sizing used in claim rows.
- `meter.dart`: `PdMeter({required CoverWindow window, required DateTime today, bool onPaper = false})` (header row, 8pt bar, footer) and `MeterBar({double fraction, Color fill, Color track, double height = 8})`.
- `paper.dart`: `ReceiptPaper({child, padding})` (paper, zigzag 12pt torn bottom, shadow-paper), `DocumentPaper({child, padding})` (paper-2, radius-xs, 6pt double rule top), `NotchedTicketPaper` (side notches and dashed stub perforation), `PaperGrain` (dot-grid painter), `DashedRule({color, thickness = 1})`, `SolidRule({color})`.
- `item_card.dart`: `ItemCard({required ItemSummary summary, VoidCallback? onTap, bool landStamp = false, VoidCallback? onLanded})` → ReceiptCard for bills, DocumentCard otherwise; one Semantics button with `summary.semanticLabel`; lifts 2pt on press; large-text layout.
- `countdown_ticket.dart`: `CountdownTicket({required ItemSummary summary, required CoverWindow window, required VoidCallback onTap, VoidCallback? onDismissed})` (Dismissible when onDismissed set).
- `vault_ticket.dart`: `VaultTicket` displays a countdown and its associated action. A ticket without an `onTap` serves as a read-only deadline callout in Bill Detail.
- `text_field.dart`: `PdTextField({required String label, required TextEditingController controller, String? hint, bool readFromBill = false, String? help, String? Function(String)? validator, TextInputType? keyboardType, TextInputAction? textInputAction, int maxLines = 1, ValueChanged<String>? onChanged, String? prefixText, TextCapitalization textCapitalization = TextCapitalization.sentences, Key? fieldKey, bool enabled = true})` — error only after the field loses focus once; clear button while editing; `PdFieldButton({required String label, required String value, String? hint, bool readFromBill = false, required VoidCallback onTap})` (field-looking tap target for dates/pickers).
- `list_row.dart`: `PdListGroup({String? header, required List<Widget> children})`, `PdListRow({required String title, String? value, Widget? trailing, bool chevron = false, bool destructive = false, IconData? actionIcon, VoidCallback? onTap, String? tag})`, `PdSwitch({required bool value, ValueChanged<bool>? onChanged})`.
- `limit_notice.dart`: `LimitNotice({required int count, required VoidCallback onReview, required VoidCallback onWaitlist})`, `LimitFootnote({required int left})`.
- `snackbar.dart`: `showPdSnackbar(BuildContext context, String message, {bool success = false, String? action, VoidCallback? onAction})` (4s, 8s with action, floating with 16 margins, surface-2/hairline/radius-md/shadow-fab).
- `sheets.dart`: `Future<T?> showPdSheet<T>(BuildContext, {required String title, String? subtitle, List<PdSheetOption<T>> options, Widget? body})`; `PdSheetOption<T>({required IconData? icon, PdGlyph? glyph, required String title, required String description, required T value, bool recommended = false})`; `Future<T?> showPdActions<T>(BuildContext, {String? title, String? message, required List<PdAction<T>> actions})` (CupertinoActionSheet; `PdAction({label, value, destructive})`, Cancel built in); `Future<DateTime?> showPdDatePicker(BuildContext, {DateTime? initial, DateTime? min, DateTime? max, String title})` (dark wheel in a modal popup, returns civil date); `Future<bool> showPdConfirm(BuildContext, {title, message, confirmLabel, destructive})`.
- `claim_ladder.dart`: `ClaimLadder({required Claim claim, required DateTime today})` shows the numbered escalation steps and identifies the current and recommended steps.
- `nav.dart`: `PdLargeTitleScaffold({required String title, Widget? trailing, required List<Widget> slivers, ScrollController? controller, String heroTag})` (CupertinoSliverNavigationBar, Bricolage large title collapsing to Inter 17/600; bg; hairline once scrolled; bottom inset space-12); `PdPushedScaffold({required String backLabel, String? kicker, String? title, TextStyle? titleStyle, TextStyle? backStyle, List<Widget> actions, required List<Widget> children, Widget? bottom, VoidCallback? onBack})` (back button, kicker and title, scrolling body with 20 margins, optional pinned bottom area); `ScanButton({required VoidCallback onTap, VoidCallback? onLongPress})`; `PdNavIcon({required Widget icon, required String semanticLabel, required VoidCallback onTap})`.
- `nav.dart`: Item details use `PdPushedScaffold(scrollBehindHeader: true)`. Back and the action group stay pinned in a transparent overlay, with the scroll view extending behind them.
- `tab_bar.dart`: On iOS 26 and later, `native_liquid_glass` embeds the system tab bar for Home, Drawer and Settings. A separate native Add action opens the same Files form without changing the selected tab. The dock stays mounted across tabs and pushed pages, and keeps the scroll inset steady. Both shells hide the dock while the keyboard is open. Older iOS and other platforms use the Flutter dock. Both shells extend content behind the bar and provide enough bottom space to scroll the final item clear.
- `glass.dart`: Floating Back, Close, Notifications and the item action group use Apple’s regular Liquid Glass throughout page transitions on iOS 26 and later. The system controls refraction and the user’s glass appearance. Each root router suppresses embedded glass during Flutter modal presentations. Older iOS and other platforms use the Flutter glass controls.
- `empty_state.dart`: `DashedTile({required String title, required String body, Widget? action})`.
- `ui/core/theme/app_theme.dart`: `ThemeData pdTheme()` (dark, scaffold bg, text selection lime, no ink splash on iOS), `CupertinoThemeData pdCupertinoTheme()` (nav large title / title styles).
