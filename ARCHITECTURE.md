# SpiderStack — Architecture Reference Guide

> SpiderStack is a demo web application built with the Spider Web Framework in Zig.

---

## Project Structure

```
spiderstack/
├── build.zig                    # Zig build configuration + generate-templates
├── docker-compose.yml           # PostgreSQL container
├── package.json                 # Dependencies (Tailwind, DaisyUI)
├── tailwind.config.js          # Tailwind configuration
├── postcss.config.js           # PostCSS configuration
├── src/
│   ├── main.zig                # Entry point - routes configuration
│   ├── embedded_templates.zig # Generated - DO NOT EDIT
│   │
│   ├── core/                   # Core functionality
│   │   ├── config/            # Configuration
│   │   ├── context/           # Request context
│   │   ├── db/                # Database + migrations
│   │   ├── errors/            # Error handling
│   │   ├── i18n/              # Internationalization
│   │   ├── middleware/         # Auth middleware
│   │   └── utils/             # Utilities
│   │
│   ├── features/              # Application features
│   │   ├── auth/              # Authentication (Google OAuth)
│   │   ├── games/            # Games CRUD
│   │   ├── home/             # Home page
│   │   └── todo/             # Todo list CRUD
│   │
│   └── shared/                # Shared templates
│       └── templates/
│           ├── layout.html
│           └── partials/      # topbar, sidebar, bottom_nav, drawer
│
└── public/
    ├── css/                   # Compiled CSS output
    ├── icons/                 # PWA icons (192, 512)
    ├── manifest.json          # PWA manifest
    └── sw.js                  # Service Worker
```

---

## Feature Structure

Every new feature must follow this structure:

```
src/features/{name}/
├── mod.zig              # Module exports
├── model.zig           # Database types and input structs
├── repository.zig      # Database access (find, create, update, delete)
├── presenter.zig       # Context building and data transformation
├── controller.zig      # HTTP handlers (index, create, update, delete)
└── views/
    ├── index.html     # Main template (full page)
    ├── modal_X.html   # Modal component (optional)
    └── item_X.html   # HTMX partial (optional)
```

---

## Model (`model.zig`)

- Definitive source of truth for the feature's types
- Defines structs for database rows and form input
- No dependencies on other features

```zig
pub const Todo = struct {
    id: i64,
    title: []const u8,
    completed: bool,
    created_at: []const u8,
    updated_at: []const u8,
};

pub const CreateInput = struct {
    title: []const u8,
};

pub const UpdateInput = struct {
    title: ?[]const u8 = null,
    completed: ?bool = null,
};
```

---

## Repository (`repository.zig`)

- Receives `alloc: std.mem.Allocator` in each operation
- Returns raw data from database
- Uses Spider's PostgreSQL driver

```zig
pub fn findAll(alloc: std.mem.Allocator) ![]Todo {
    const sql = "SELECT id, title, completed, created_at, updated_at FROM todos ORDER BY created_at DESC";
    return try db.query(Todo, alloc, sql, .{});
}

pub fn create(alloc: std.mem.Allocator, input: CreateInput) !?Todo {
    const sql = "INSERT INTO todos (title) VALUES ($1) RETURNING id, title, completed, created_at, updated_at";
    return try db.queryOne(Todo, alloc, sql, .{input.title});
}

pub fn delete(alloc: std.mem.Allocator, id: i64) !void {
    const sql = "DELETE FROM todos WHERE id = $1";
    _ = try db.query(void, alloc, sql, .{id});
}
```

### Database API

```zig
// SELECT multiple rows → []T
db.query(Todo, alloc, "SELECT ...", .{});

// SELECT single row → ?T
db.queryOne(Todo, alloc, "SELECT ... LIMIT 1", .{});

// INSERT/UPDATE/DELETE
db.query(void, alloc, "INSERT/DELETE ...", .{});
```

---

## Presenter (`presenter.zig`)

- Builds context for templates
- Includes BaseContext for layout data
- Handles i18n

```zig
pub const TodoContext = struct {
    base: BaseContext,
    todos: []const Todo,
};

pub fn buildContext(alloc: std.mem.Allocator, req: anytype, todos: []const Todo) !TodoContext {
    const locale_raw = req.locale orelse "pt-BR";
    const locale = i18n.localeFromStr(locale_raw);
    const base = try base_context.build(alloc, req, locale);

    return TodoContext{
        .base = base,
        .todos = todos,
    };
}
```

### BaseContext

Every feature context must include `base: BaseContext` for the layout:

```zig
pub const BaseContext = struct {
    locale: i18n.Locale,
    // ... other fields
};
```

---

## Controller (`controller.zig`)

- HTTP request handling
- Calls repository and presenter
- Uses chuckBerry for rendering

```zig
pub fn index(alloc: std.mem.Allocator, req: *Request) !Response {
    const todos = try repository.findAll(alloc);
    defer alloc.free(todos);

    const context = try presenter.buildContext(alloc, req, todos);
    return spider.chuckBerry(alloc, req, "todo/index", context);
}

pub fn create(alloc: std.mem.Allocator, req: *Request) !Response {
    const input = try req.parseForm(alloc, model.CreateInput);
    _ = try repository.create(alloc, input);

    return Response.redirect(alloc, "/todo");
}
```

### HTMX Support

For HTMX partial responses:

```zig
fn isHxRequest(req: *Request) bool {
    return req.headers.get("HX-Request") != null;
}

pub fn create(alloc: std.mem.Allocator, req: *Request) !Response {
    const input = try req.parseForm(alloc, model.CreateInput);
    const todo = (try repository.create(alloc, input)) orelse return Response.text(alloc, "Error");

    if (isHxRequest(req)) {
        const context = try presenter.buildItemContext(alloc, req, todo);
        return spider.chuckBerry(alloc, req, "todo/item_todo", context);
    }

    return Response.redirect(alloc, "/todo");
}
```

---

## Template System

### Embedded Templates (chuckBerry)

Templates are embedded at compile time. Run `zig build` after creating new templates.

```zig
// Render embedded template
return spider.chuckBerry(alloc, req, "todo_index", context);
```

### Template Naming Convention

| File Path | Template Name |
|----------|---------------|
| `features/todo/views/index.html` | `todo_index` |
| `features/games/views/modal_game.html` | `games_modal_game` |
| `features/todo/views/item_todo.html` | `todo_item_todo` |
| `shared/templates/partials/topbar.html` | `partials_topbar` |

### Layout (`layout.html`)

```html
{% block "base" %}
<!DOCTYPE html>
<html lang="{{ base.locale | default:"pt-BR" }}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{ title | default:"SpiderStack" }}</title>
  <!-- PWA -->
  <link rel="manifest" href="/manifest.json">
  <meta name="theme-color" content="#facc15">
  <!-- Scripts -->
  <script src="/htmx.min.js"></script>
  <script defer src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js"></script>
  <script>
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js');
    }
  </script>
</head>
<body x-data="{ drawerOpen: false }" ...>
  {% include "partials_topbar" %}
  {% include "partials_drawer" %}

  <main id="main">
    {% template "content" %}
  </main>

  {% include "partials_bottom_nav" %}
</body>
</html>
{% end %}
```

### Extends and Block

```html
{% extends "layout" %}
{% block "content" %}
  <h1>My Page</h1>
{% end %}
```

### Include (Component)

```html
<!-- Include component -->
{% include "todo_item_todo" %}
```

### Conditionals

```html
{% if game.rank <= 3 %}
  <!-- medal display -->
{% else %}
  <!-- rank number + actions -->
{% endif %}
```

### Loops

```html
{% for todo in todos %}
  {% include "todo_item_todo" %}
{% endfor %}
```

---

## Partial Components

### Global Partials (`src/shared/templates/partials/`)

- `topbar.html` — Top navigation bar
- `sidebar.html` — Desktop sidebar
- `bottom_nav.html` — Mobile bottom navigation
- `drawer.html` — Mobile slide-in drawer

### Feature Partials (`src/features/{name}/views/`)

- `modal_X.html` — Reusable modal components
- `item_X.html` — Single item for HTMX lists

---

## Routes (`main.zig`)

```zig
const templates = @import("embedded_templates.zig").EmbeddedTemplates;

var server = try spider.Spider.init(arena, io, "127.0.0.1", 8080, .{
    .templates = templates,
});

server
    .get("/", home.controller.index)
    .get("/todo", todo.controller.index)
    .post("/todo/create", todo.controller.create)
    .post("/todo/:id/update", todo.controller.update)
    .post("/todo/:id/delete", todo.controller.delete)
    .get("/games", games.controller.index)
    .post("/games/create", games.controller.create)
    .post("/games/:id/update", games.controller.update)
    .post("/games/:id/delete", games.controller.delete)
    .use(middleware.auth)
    .listen() catch |err| { ... };
```

---

## HTMX + Alpine.js Conventions

### HTMX for Server Interactions

```html
<!-- Create with HTMX -->
<form hx-post="/todo/create" hx-target="#todo-list" hx-swap="beforeend">
  <input name="title" placeholder="Nova tarefa..." required>
  <button>Adicionar</button>
</form>

<!-- Toggle completed -->
<button hx-post="/todo/{{ todo.id }}/update"
        hx-vals='{"completed": "{% if todo.completed %}false{% else %}true{% endif %}"}'
        hx-target="#todo-{{ todo.id }}"
        hx-swap="outerHTML">
  {% if todo.completed %}✓{% endif %}
</button>

<!-- Delete -->
<button hx-post="/todo/{{ todo.id }}/delete"
        hx-target="#todo-{{ todo.id }}"
        hx-swap="outerHTML">
  Delete
</button>
```

### Alpine.js for Local UI State

```html
<!-- Modal state -->
<div x-data="{ open: false }">
  <button @click="open = true">Open</button>
  
  <div x-show="open" @keydown.escape.window="open = false">
    Modal content
  </div>
</div>
```

### Skeleton Loading

```html
<div class="htmx-indicator">
  <div class="bg-zinc-800 rounded-3xl h-48 animate-pulse"></div>
</div>
```

---

## PWA Support

### manifest.json

```json
{
  "name": "SpiderStack",
  "short_name": "SpiderStack",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#09090b",
  "theme_color": "#facc15",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```

### Service Worker (sw.js)

```js
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', () => self.clients.claim());
```

### Layout PWA Meta Tags

```html
<link rel="manifest" href="/manifest.json">
<meta name="theme-color" content="#facc15">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<link rel="apple-touch-icon" href="/icons/icon-192.png">
<script>
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js');
  }
</script>
```

---

## Form Parsing

```zig
pub const CreateInput = struct {
    title: []const u8,
};

pub fn create(alloc: std.mem.Allocator, req: *Request) !Response {
    const input = try req.parseForm(alloc, model.CreateInput);
    // input.title is available
}
```

---

## Rules for AI Agents

1. **Always run `zig build`** after changes — verify compilation passes
2. **Always use embedded templates** — run `zig build` to regenerate after creating new .html files
3. **Template naming**: path `features/todo/views/index.html` → `todo_index`
4. **Never use deprecated DB API**: always use `db.query()` and `db.queryOne()`
5. **HTMX partials**: render the item template, not the full page
6. **Include convention**: use correct template name (e.g., `games_card_game`, not `card_game`)
7. **Always include BaseContext** in presenter contexts for layout data
8. **Never hardcode user-facing strings** — use i18n when possible
9. **New features**: follow the Feature Structure pattern
10. **PWA**: add manifest, service worker, and meta tags for installable app