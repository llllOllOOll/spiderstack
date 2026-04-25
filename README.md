# Demo Spider - SpiderStack Web Application

## Overview

This is a demo project showing how to build a complete web application using the **Spider Web Framework** in **Zig**, with several modern technologies integrated.

**Official Website**: [https://www.spiderme.org/](https://www.spiderme.org/)

## Tech Stack

### Backend
- **Language**: Zig 0.17.0-dev
- **Web Framework**: [Spider](https://www.spiderme.org/) v0.2.0 - full-featured web framework for Zig
- **Database**: PostgreSQL 16 (via Spider's native driver)
- **Authentication**: JWT + OAuth2 (Google Login)
- **HTTP Client**: [pacman](https://github.com/llllOllOOll/pacman) - Fetch API-inspired Zig HTTP client
- **Build System**: Spider handles libpq linking automatically

### Frontend
- **CSS**: Tailwind CSS + DaisyUI
- **Template**: HTML server-side rendering
- **Build**: PostCSS + Autoprefixer

### Infrastructure
- **Container**: Docker + Docker Compose
- **Zig Package Manager**: Built-in (build.zig)

## Features

### 1. Authentication System
- Unified login/register interface
- Login via OAuth2 with Google
- Email/password authentication
- JWT token generation and validation
- Secure cookies for session
- User locale support
- Role-Based Access Control (RBAC)

### 2. Games Management (CRUD)
- List games from database
- Create new game
- Update existing game
- Delete game
- Modal-based game editing
- Alpine.js for reactive UI components

### 3. Todo List (CRUD completo com HTMX)
- List, create, update, delete tasks
- HTMX for seamless updates without page reload
- Toggle completed status
- Dark theme UI

### 4. PWA Support
- Web manifest for installable app
- Service worker for offline capability
- Apple mobile web app support
- Theme color and icons

### 5. Mobile Drawer Menu (Alpine.js)
- Slide-in drawer navigation on mobile
- Alpine.js for reactive UI
- Smooth transitions

### 6. Skeleton Loading
- Loading placeholders during navigation

### 7. HTTP Client Integration (pacman)
- Fetch API-inspired Zig HTTP client
- Used for Google OAuth authentication
- Built-in JSON serialization/deserialization
- Arena-based memory management

### 8. Template System com chuckBerry
- Server-side rendering com embedded templates
- Componentização com partials (topbar, sidebar, bottom_nav, drawer)
- Layout inheritance

### 8. Internationalization (i18n)
- Support for Portuguese (pt-BR) and English (en-US)
- Locale based on Accept-Language header
- Date and number formatting

### 9. Middleware
- JWT authentication
- Public vs private routes

### 10. Database Migrations
- Automated migration system
- Schema version control

## Project Structure

```
spiderstack/
├── build.zig                    # Zig build configuration
├── docker-compose.yml           # PostgreSQL container
├── package.json                 # Dependencies (Tailwind, DaisyUI)
├── tailwind.config.js          # Tailwind configuration
├── postcss.config.js           # PostCSS configuration
├── .env                        # Environment variables
│
├── src/
│   ├── main.zig                # Entry point - routes and configuration
│   ├── root.zig               # Root module
│   ├── embedded_templates.zig # Generated embedded templates
│   │
│   ├── core/                   # Core functionality
│   │   ├── config/           # Configuration
│   │   ├── context/          # Request context
│   │   ├── db/               # Database + migrations
│   │   ├── errors/           # Error handling
│   │   ├── i18n/            # Internationalization
│   │   ├── middleware/     # Auth middleware
│   │   └── utils/           # Utilities
│   │
│   ├── features/              # Application features
│   │   ├── auth/            # Authentication (Google OAuth)
│   │   ├── games/           # Games CRUD
│   │   ├── home/           # Home page
│   │   └── todo/           # Todo list CRUD
│   │
│   └── shared/               # Shared templates
│       └── templates/       # HTML layout, partials
│           └── partials/   # topbar, sidebar, bottom_nav, drawer
│
└── public/
    ├── css/                  # Compiled CSS output
    ├── icons/                # PWA icons (192, 512)
    ├── manifest.json         # PWA manifest
    └── sw.js                 # Service Worker
```

## How to Run

### 1. Start PostgreSQL
```bash
docker-compose up -d
```

### 2. Build CSS (optional)
```bash
npm run build:css
# or watch mode
npm run watch:css
```

### 3. Build and run application
```bash
zig build run
```

The application will be available at `http://127.0.0.1:8080`

### 4. Prerequisites

**PostgreSQL Client Library (libpq)** is installed automatically by Spider. Just ensure you have the development headers available:

#### Arch Linux
```bash
pacman -S postgresql-libs
```

#### Debian/Ubuntu
```bash
sudo apt install libpq-dev
```

#### Fedora/RHEL
```bash
sudo dnf install postgresql-devel
```

#### macOS (Homebrew)
```bash
brew install libpq
```

> **Note:** Spider handles `libpq` linking automatically. No manual linking required in your build.zig!

### 5. Tests
```bash
# Unit tests (no database required)
zig build test

# Integration tests (requires database)
zig build test-integration
```

## Routes

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/` | Home page | ✅ |
| GET | `/login` | Login page | ❌ |
| GET | `/auth/google` | Redirect to Google | ❌ |
| GET | `/auth/google/callback` | OAuth callback (uses pacman HTTP client) | ❌ |
| POST | `/auth/email/register` | Email registration | ❌ |
| POST | `/auth/email/login` | Email login | ❌ |
| GET | `/logout` | Logout user | ✅ |
| GET | `/todo` | Todo list | ✅ |
| POST | `/todo/create` | Create todo | ✅ |
| POST | `/todo/:id/update` | Update todo | ✅ |
| POST | `/todo/:id/delete` | Delete todo | ✅ |
| GET | `/games` | Game list | ✅ |
| POST | `/games/create` | Create game | ✅ |
| POST | `/games/:id/update` | Update game | ✅ |
| POST | `/games/:id/delete` | Delete game | ✅ |

## Environment Variables

```env
# Database
POSTGRES_HOST=localhost
POSTGRES_PORT=5434
POSTGRES_USER=spider
POSTGRES_PASSWORD=spider
POSTGRES_DB=spiderdb

# Google OAuth
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_client_secret
GOOGLE_REDIRECT_URI=http://localhost:8080/auth/google/callback

# JWT
JWT_SECRET=your_secret_key
```

## Data Model

### Table: users
```sql
id SERIAL PRIMARY KEY
email VARCHAR(255) UNIQUE NOT NULL
name VARCHAR(255)
locale VARCHAR(10) DEFAULT 'pt-BR'
locale_set BOOLEAN DEFAULT FALSE
created_at TIMESTAMPTZ DEFAULT NOW()
```

### Table: games
```sql
id SERIAL PRIMARY KEY
name VARCHAR(255) NOT NULL
platform VARCHAR(100)
release_year INTEGER
genre VARCHAR(100)
developer VARCHAR(255)
sales_millions DECIMAL(10,2)
rating DECIMAL(3,1)
created_at TIMESTAMPTZ DEFAULT NOW()
```

### Table: todos
```sql
id SERIAL PRIMARY KEY
title VARCHAR(255) NOT NULL
completed BOOLEAN DEFAULT FALSE
created_at TIMESTAMPTZ DEFAULT NOW()
updated_at TIMESTAMPTZ DEFAULT NOW()
```

## Spider Framework Concepts

### Initialization
```zig
const templates = @import("embedded_templates.zig").EmbeddedTemplates;

var server = try spider.Spider.init(arena, io, "127.0.0.1", 8080, .{
    .templates = templates,
});
```

### HTTP Client (pacman)
The project uses the **pacman** HTTP client for external API calls:

```zig
// Google OAuth token request
var token_res = try http_client.post(io, arena_allocator, "https://oauth2.googleapis.com/token", .{
    .body = .{ .form = &.{
        .{ "code", code },
        .{ "client_id", config.client_id },
        .{ "client_secret", config.client_secret },
        .{ "redirect_uri", config.redirect_uri },
        .{ "grant_type", "authorization_code" },
    } },
});
defer token_res.deinit();

// Parse JSON response
const TokenResponse = struct { access_token: []const u8 };
const parsed_token = try token_res.json(TokenResponse);
```

pacman provides:
- Fetch API-inspired interface
- Built-in JSON serialization
- Query parameters and URL path params
- Arena-based memory management
- Full std.Io support for Zig 0.17+

### Embedded Templates (generate-templates)
Templates are embedded at compile time via `generateEmbeddedTemplates` in build.zig:
```zig
gen.addArg("src/embedded_templates.zig");
```

### Routes
```zig
server
    .get("/", home.controller.index)
    .post("/games/create", games.controller.create)
    .use(middleware.auth)  // applies to all following routes
```

### Responses
```zig
// Redirect
return Response.redirect(alloc, "/path");

// Render view with chuckBerry (embedded templates)
return spider.chuckBerry(alloc, req, "home/index", context);

// Text response
return Response.text(alloc, "message");
```

### Database
```zig
// Simple query
const result = try db.query(MyStruct, alloc, "SELECT * FROM table", .{});

// Insert/Update with RETURNING
const new_row = try db.queryOne(MyStruct, alloc, "INSERT INTO ... RETURNING ...", .{});

// Transaction
var tx = try db.begin();
defer tx.rollback();
// ... operations
try tx.commit();
```

## Build and Deployment

### Release build
```bash
zig build -Drelease-safe
# or
zig build -Drelease-fast
```

### Binary output
The compiled binary will be at `zig-out/bin/spiderstack`

## Contact

- **Author**: Seven
- **Email**: 7b37b3@gmail.com
- **Twitter**: [@1111O11OO11](https://x.com/1111O11OO11)

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed architecture patterns and conventions

## References

- [Spider Framework](https://www.spiderme.org/)
- [SpiderStack GitHub](https://github.com/llllOllOOll/spiderstack)
- [pacman HTTP Client](https://github.com/llllOllOOll/pacman)
- [Zig Language](https://ziglang.org/)
- [Tailwind CSS](https://tailwindcss.com/)
- [DaisyUI](https://daisyui.com/)
- [PostgreSQL](https://www.postgresql.org/)