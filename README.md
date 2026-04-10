# Demo Spider - SpiderStack Web Application

## Overview

This is a demo project showing how to build a complete web application using the **Spider Web Framework** in **Zig**, with several modern technologies integrated.

**Official Website**: [https://www.spiderme.org/](https://www.spiderme.org/)

## Tech Stack

### Backend
- **Language**: Zig 0.16.0-dev.2984+cb7d2b056
- **Web Framework**: [Spider](https://www.spiderme.org/) - full-featured web framework for Zig
- **Database**: PostgreSQL 16 (via Spider's native driver)
- **Authentication**: JWT + OAuth2 (Google Login)

### Frontend
- **CSS**: Tailwind CSS + DaisyUI
- **Template**: HTML server-side rendering
- **Build**: PostCSS + Autoprefixer

### Infrastructure
- **Container**: Docker + Docker Compose
- **Zig Package Manager**: Built-in (build.zig)

## Features

### 1. Authentication System
- Login via OAuth2 with Google
- JWT token generation and validation
- Secure cookies for session
- User locale support

### 2. Games Management (CRUD)
- List games from database
- Create new game
- Update existing game
- Delete game

### 3. Internationalization (i18n)
- Support for Portuguese (pt-BR) and English (en-US)
- Locale based on Accept-Language header
- Date and number formatting

### 4. Middleware
- JWT authentication
- Public vs private routes

### 5. Database Migrations
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
│   │   └── home/           # Home page
│   │
│   └── shared/               # Shared templates
│       └── templates/       # HTML layout, partials
│
└── public/
    └── css/                  # Compiled CSS output
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

**PostgreSQL Client Library (libpq)** is required to compile this project.

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

#### Verify Installation
```bash
pkg-config --exists libpq && echo "ok"
```

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
| GET | `/auth/google/callback` | OAuth callback | ❌ |
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

## Spider Framework Concepts

### Initialization
```zig
var server = try spider.Spider.init(arena, io, "127.0.0.1", 8080, .{ .layout = layout });
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

// Render view with context
return spider.renderView(alloc, req, view_content, context);

// Text response
return Response.text(alloc, "message");
```

### Database
```zig
// Simple query
const result = try db.query(MyStruct, alloc, "SELECT * FROM table", .{});

// Insert/Update
try db.queryExecute(void, alloc, "INSERT INTO ...", .{});

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

## References

- [Spider Framework](https://www.spiderme.org/)
- [SpiderStack GitHub](https://github.com/llllOllOOll/spiderstack)
- [Zig Language](https://ziglang.org/)
- [Tailwind CSS](https://tailwindcss.com/)
- [DaisyUI](https://daisyui.com/)
- [PostgreSQL](https://www.postgresql.org/)