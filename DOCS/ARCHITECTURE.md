# Smoney — Architecture Reference Guide

> **Memory Management Notice**: The memory patterns in this document are under review.
> A dedicated analysis session identified potential use-after-free issues in the current
> ArenaAllocator pattern. See `TODO: memory-audit` for details before implementing new features.

---

## Project Structure

```
├── assets/              # 
src/
├── features/              # Feature modules (primary location for new code)
│   ├── accounts/
│   ├── bills/
│   ├── transactions/
│   └── tests/             # Dev scaffolding only — do not follow as pattern
├── services/              # Cross-feature business logic
│   ├── installments/
│   └── statements/
├── shared/                # Shared components used by all features
│   ├── base_context.zig
│   └── validation.zig
├── middleware/
│   ├── auth.zig
│   └── locale.zig
├── layout/
│   └── base.html          # Root layout template
├── use_cases/             # Cross-feature use cases
│   └── user/
├── utils/                 # Utility libraries
│   ├── currency/
│   ├── date/
│   └── i18n/
├── db/
│   └── migrations/        # SQL migration files
├── helpers.zig
└── main.zig
```

---

## Feature Structure

Every new feature must follow this structure:

```
src/features/{name}/
  ├── model.zig         — definitive types and enums
  ├── repository.zig    — database access
  ├── presenter.zig     — data transformation and final context
  ├── controller.zig    — orchestration only
  ├── root.zig          — re-exports for main.zig
  ├── use_cases/        — only if complex business logic exists
  └── views/
      ├── index.html    — main template
      └── row.html      — HTMX partial if needed
```

---

## Model (`model.zig`)

- Definitive source of truth for the feature's types
- Defines structs, enums, and conversion methods
- No dependencies on other local features
- Presentation fields (category_name, account_name from JOINs) do NOT belong here

```zig
pub const RecurringTransaction = struct {
    id: i32,
    title: []const u8,
    amount: f64,
    frequency: Frequency,
    active: bool,
};

pub const Frequency = enum {
    weekly, biweekly, monthly, quarterly, yearly,

    pub fn fromString(s: []const u8) !Frequency { ... }
};
```

---

## Repository (`repository.zig`)

- Receives `alloc: std.mem.Allocator` in each operation
- Returns raw data — no formatting, no transformation
- Depends only on `model.zig`
- No `.deinit()` calls needed — arena handles memory automatically

```zig
pub fn listByUser(alloc: std.mem.Allocator, user_id: i32) ![]RecurringTransaction
pub fn create(alloc: std.mem.Allocator, input: CreateInput) !RecurringTransaction
pub fn delete(alloc: std.mem.Allocator, id: i32) !void
```

### Database API

```zig
db.query(Account, arena, sql, .{user_id})     // SELECT multiple → []T
db.queryOne(Account, arena, sql, .{id})        // SELECT one     → ?T
db.query(i32, arena, sql, .{...})              // INSERT RETURNING id
db.query(void, arena, sql, .{...})             // INSERT/UPDATE/DELETE
```

### SQL Alias Rule

If a struct field name differs from the column name, use `column AS field`:

```sql
SELECT
    t.id,
    t.amount,
    c.name AS category_name,
    a.name AS account_name
FROM transactions t
LEFT JOIN categories c ON t.category_id = c.id
LEFT JOIN accounts a ON t.account_id = a.id
```

### Database Transactions

```zig
var tx = try db.begin();
defer tx.rollback(); // automatic rollback on failure

const id = try tx.query(i32, arena, "INSERT ... RETURNING id", .{...});
try tx.query(void, arena, "UPDATE accounts SET balance = ...", .{...});

try tx.commit();
```

Never use manual `BEGIN`/`COMMIT` — always use the transaction API.

---

## Presenter (`presenter.zig`)

- Receives raw slices from repository — always `[]Account`, never `[]AccountRow`
- Handles all transformation — currency, dates, i18n, grouping
- Calls `BaseContext.build(alloc, user, locale)` internally
- Builds the final context with `base: BaseContext` embedded
- All allocations use the received `alloc` parameter
- `buildContext` is the main entry point

```zig
pub fn toRow(alloc: std.mem.Allocator, t: RecurringTransaction, locale: i18n.Locale) !RecRow

pub fn toGroups(alloc: std.mem.Allocator, transactions: []const RecurringTransaction, locale: i18n.Locale) ![]RecGroup

// Receives raw slices — conversion happens inside
pub fn buildContext(
    alloc: std.mem.Allocator,
    user: anytype,
    locale: i18n.Locale,
    transactions: []const RecurringTransaction,
    accounts: []const Account,     // raw — not []AccountRow
    categories: []const Category,  // raw — not []CategoryRow
) !RecurringContext
```

Every feature context embeds `BaseContext`:

```zig
pub const RecurringContext = struct {
    base: BaseContext,  // nav, user, locale — never duplicate these fields
    groups: []RecGroup,
    accounts: []AccountRow,
    page_title: []const u8,
    // ...
};
```

---

## Controller (`controller.zig`)

- Auth + locale + repository calls + `presenter.buildContext` + `renderView`
- No data transformation
- No `defer alloc.free` on data that goes into the Response
- Templates embedded here via `@embedFile`
- Passes `alloc` received from Spider directly to all layers

```zig
const view     = @embedFile("views/index.html");
const row_view = @embedFile("views/row.html");

pub fn renderRecurring(alloc: std.mem.Allocator, req: *Request) !Response {
    const user_id = try auth.getUserId(req);
    const user = try UserRepository.init(alloc).findById(user_id) orelse return error.Unauthorized;
    const locale = resolveLocale(user, req);

    const transactions = try RecurringRepository.init(alloc).listByUser(user_id, null);
    const accounts     = try AccountRepository.listByUser(alloc, user_id);
    const categories   = try CategoryRepository.init(alloc).listAll();

    const data = try presenter.buildContext(alloc, user, locale, transactions, accounts, categories);
    return spider.renderView(alloc, req, view, data);
}
```

---

## root.zig

Re-exports public functions from controller. Allows changing internal structure without touching `main.zig`.

```zig
pub const renderRecurring = @import("controller.zig").renderRecurring;
pub const handleCreate    = @import("controller.zig").handleCreate;
pub const handleDelete    = @import("controller.zig").handleDelete;
```

---

## use_cases/

Only create when there is complex business logic involving multiple entities.

- **Justified**: calculating projections, processing installments, creating cascading transactions
- **Not justified**: simple CRUD, status toggle, direct delete

---

## Memory Management

> ### TODO: memory-audit
>
> A confirmed use-after-free issue was identified in the current ArenaAllocator pattern.
>
> **Root cause**: `Response.html` stores the body slice directly without copying:
> ```zig
> res.body = content; // stores pointer — does not dupe
> ```
> If the controller creates a local `ArenaAllocator` with `defer arena.deinit()`, the arena
> is freed on return — before Spider serializes the response to the socket. This leaves
> `Response.body` pointing to freed memory.
>
> **Why it works silently in debug**: GPA does not immediately reuse freed memory, so the
> pointer still reads valid-looking data. In release mode or under memory pressure it crashes.
>
> **Files to audit**: all controllers in `src/controllers/` and `src/features/` that use
> the pattern below.
>
> **Do not introduce new local ArenaAllocator usage in controllers until the audit is complete.**

### Current pattern (in use — under review)

```zig
pub fn renderTransactions(alloc: std.mem.Allocator, req: *Request) !Response {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const transactions = try TransactionRepository.init(arena_allocator).listByUser(user_id);
    const data = try buildContext(arena_allocator, locale, user, transactions);

    return spider.renderView(arena_allocator, req, view, data);
    // ⚠ arena freed here — Response.body points to freed memory
}
```

### Allocator strategy

| Allocator | Where | Purpose |
|---|---|---|
| `init.gpa` | `main.zig` | Server init, DB init, migrations |
| `init.arena` | `main.zig` | Process-lifetime data only (CLI args, config) |
| Spider connection arena | handler `alloc` param | Per-request — managed by Spider |

### Money fields

- **Zig**: always `i64` (cents)
- **PostgreSQL**: always `numeric(12,2)`
- Never use `f64` for money storage

---

## BaseContext (`src/shared/base_context.zig`)

Global data used by the root layout. Called inside `presenter.buildContext` — never in the controller.

```zig
pub const BaseContext = struct {
    locale: i18n.Locale,
    user_name: []const u8,
    user_initials: [2]u8,
    user_email: []const u8,
    user_avatar: []const u8,
    nav_overview: []const u8,
    nav_accounts: []const u8,
    nav_transactions: []const u8,
    nav_recurring: []const u8,
    nav_bills: []const u8,
    nav_budget: []const u8,
    nav_profile: []const u8,
    dropdown_profile: []const u8,
    dropdown_logout: []const u8,
};

pub fn build(alloc: std.mem.Allocator, user: anytype, locale: i18n.Locale) !BaseContext
```

- i18n strings point to the binary — no allocation
- User strings (`name`, `email`, `avatar`) are slices borrowed from the caller

---

## base.html (`src/layout/base.html`)

- Root template of the application
- Receives any `*Context` that has `base: BaseContext`
- Renders nav, header, and user dropdown via `context.base.*`
- The `content` block is filled by the feature template

---

## Template Rendering

### Full page (with layout)

```zig
return spider.renderView(alloc, req, view, data);
```

### HTMX fragment (no layout)

```zig
const html = try spider.template.render(row_view, row_data, alloc);
return Response.html(alloc, html);
```

Never mix these two patterns.

---

## Template Engine

Spider uses a built-in Jinja-inspired template engine.

### Variable interpolation
```html
{{ variable }}
{{ object.field }}
{{ list.len }}
```

### Conditionals
```html
{% if condition %}...{% endif %}
{% if condition %}...{% else %}...{% endif %}
{% if condition %}...{% elif other %}...{% else %}...{% endif %}
```

Supported operators: `==`, `!=`, `>`, `>=`, `<`, `<=`, `!`, `and`, `or`

### Loops
```html
{% for item in list %}...{% endfor %}
```

### Raw blocks (for Alpine.js)
```html
{% raw %}{{ alpine_variable }}{% endraw %}
```

### Layout blocks
```html
{% block "base" %}...{% end %}
{% block "content" %}...{% end %}
{% template "content" %}
```

### Default filter
```html
{{ variable | default:"fallback" }}
```

### Rules
- Wrap Alpine.js `{{ }}` expressions in `{% raw %}`
- Full pages: `{% block "content" %}` rendered via `spider.renderView()`
- HTMX partials: plain HTML rendered via `spider.template.render()` — no block tags
- Never use JavaScript `Date()` for dates shown to users — always pass from server
- `.len` works on lists: `{% if items.len > 0 %}`

---

## Available Utilities

### `src/utils/currency/root.zig`
```zig
formatToAllocClean(alloc, f64) ![]const u8
formatFromCents(alloc, i64) ![]const u8
parseCents(s: []const u8) !i64
```

### `src/utils/date/root.zig`
```zig
today(alloc) ![]const u8
todayDate() Date
parse(date_str) !Date
nextRecurrence(alloc, current, frequency, day_of_month) ![]const u8
parseDateLabel(alloc, date_str, locale) ![]const u8
```

### `src/utils/i18n/root.zig`
```zig
t(locale, comptime key) []const u8   // static — no allocation
localeFromStr(s) Locale
monthName(locale, month) []const u8
pub const Locale = enum { pt_BR, en_US };
```

### `src/middleware/auth.zig`
```zig
getUserId(req) !i32
```

### `src/middleware/locale.zig`
```zig
resolveLocale(user, header) Locale
```

### `src/helpers.zig`
```zig
getUserIdFromRequest(req) !i32
getInitials(name) [2]u8
parseFloatSafe(val, field_name) f64
parseDateLabel(alloc, date_str, locale) ![]u8
```

### `src/shared/validation.zig`
Input validation utilities — available to all features.

---

## Migrations (`src/db/migrations/`)

- Filename format: `YYYYMMDDHHMMSS_description.sql`
- Never edit an existing migration — always create a new one
- Register new migrations in `migrations.zig`
- Executed automatically at startup via `migrations.run(allocator)`

---

## Services (`src/services/`)

Business logic that crosses multiple features.

Complex subdomains have their own structure:

```
src/services/
  ├── dashboard_service.zig
  ├── projection_service.zig
  ├── installments/
  │   ├── model.zig
  │   ├── repository.zig
  │   ├── service.zig
  │   ├── use_cases/
  │   └── root.zig
  └── statements/
```

---

## Cross-feature Use Cases (`src/use_cases/`)

Use cases that span multiple features live outside of features:

```
src/use_cases/user/
  ├── find_or_create_oauth.zig
  └── find_or_create_user.zig
```

---

## Legacy (being migrated)

| Location | Status | Destination |
|---|---|---|
| `src/views/` | legacy | `src/features/{name}/views/` |
| `src/models/` | legacy | `src/features/{name}/model.zig` |
| `src/repositories/` | legacy | `src/features/{name}/repository.zig` |
| `src/controllers/` | legacy | `src/features/{name}/` |

When migrating: move files, update imports, keep the original until confirmed no other file depends on it.

---

## Frontend Conventions

- **HTMX**: use for all server interactions — no fetch/axios
- **Alpine.js**: local UI state only — dropdowns, tabs, form state
- **i18n**: all user-facing strings via `i18n.t()` — no hardcoded labels in templates
- **Dates**: always passed from server — never use JavaScript `Date()` for business logic

---

## Zig 0.16 Patterns

### ArrayList initialization

```zig
// ✅ correct
var list: std.ArrayList(T) = .empty;
var list = try std.ArrayList(T).initCapacity(allocator, capacity);

// ❌ deprecated
var list = std.ArrayList(T).init(allocator);
```

### ArrayList cleanup

```zig
// Primitive types
defer list.deinit(allocator);

// Strings with arena — no iteration needed
defer list.deinit(arena.allocator());

// Strings without arena
defer {
    for (list.items) |str| allocator.free(str);
    list.deinit(allocator);
}
```

---

## Rules for AI Agents

1. Never create a new feature outside `src/features/`
2. Never use deprecated DB API: `queryParams`, `queryWith`, `queryAs`, `MappedRows`, `queryConn`
3. Always use current Spider API: `db.query(T, arena, sql, params)` and `db.queryOne(T, arena, sql, params)`
4. Always use transaction API (`db.begin()`) for atomic operations — never manual BEGIN/COMMIT
5. Never store `f64` for money — always `i64` (cents)
6. Never put presentation fields (joined names, icons) in `model.zig`
7. Never hardcode labels in HTML — always `i18n.t()`
8. Always run `zig build` after changes and fix all errors before finishing
9. Always check `src/utils/` before writing new utility functions
10. New migrations: add SQL file to `src/db/migrations/` and register in `migrations.zig`
11. Never use localStorage or client-side state for server-side data
12. Always use `var list: std.ArrayList(T) = .empty` for ArrayList initialization
13. Read the memory audit TODO before implementing any new controller
14. `src/features/tests/` is dev scaffolding only — do not use as architecture reference
15. Presenter receives raw slices — never pre-converted rows
16. `buildContext` lives in presenter — never in controller
