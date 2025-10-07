# Versioned Notes Backend

A Rails 8 API-only application providing immutable, versioned note-taking with collaborative features. Built with append-only version history, transactional consistency, and comprehensive authorization.

## 🎯 Features

- **Immutable Versioning**: Append-only version history with atomic head pointer updates
- **Real-time Collaboration**: Live presence, typing indicators, and instant updates via Action Cable
- **Collaborative Editing**: Role-based access control (owner/editor/viewer)
- **Note Forking**: Create independent copies of notes with full version history
- **Conflict Detection**: Base version ID checking for concurrent edits with real-time notifications
- **Flexible Visibility**: Private, link-shareable, or public notes
- **RESTful JSON API**: Versioned API with pagination and standard error formats
- **Comprehensive Authorization**: Pundit policies for fine-grained access control

## 📋 Prerequisites

- Ruby 3.4.4
- Docker & Docker Compose (for PostgreSQL)
- Bundler

## 🚀 Quick Start

### 1. Start PostgreSQL with Docker

```bash
docker-compose up -d postgres
```

This starts PostgreSQL on `localhost:5432` with:
- Username: `postgres`
- Password: `postgres`
- Database: `versioned_notes_development`

### 2. Install Dependencies

```bash
bundle install
```

### 3. Setup Database

```bash
# Create databases
rails db:create

# Run migrations
rails db:migrate

# Seed sample data
rails db:seed
```

### 4. Run the Application

```bash
rails server
```

API will be available at `http://localhost:3000`

## 🧪 Running Tests

```bash
# Run all specs
bundle exec rspec

# Run with documentation format
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/models/version_spec.rb

# Run only model specs
bundle exec rspec spec/models
```

**Test Coverage**: 450+ specs covering models, services, policies, and API endpoints.

## 📊 Database Schema (ERD)

```
┌─────────────┐
│   users     │
├─────────────┤
│ id          │──┐
│ email       │  │
│ password    │  │
└─────────────┘  │
                 │
                 │ owner_id
┌─────────────┐  │         ┌──────────────┐
│   notes     │◄─┘         │  versions    │
├─────────────┤            ├──────────────┤
│ id          │───────────►│ id           │
│ owner_id    │   note_id  │ note_id      │
│ head_version_id│◄────────│ author_id    │
│ title       │            │ parent_version_id │
│ visibility  │            │ content      │ (immutable)
└─────────────┘            │ summary      │
     │                     │ created_at   │
     │                     └──────────────┘
     │
     ├──────────────────┐
     │                  │
     ▼                  ▼
┌──────────────┐  ┌────────────┐
│collaborators │  │   forks    │
├──────────────┤  ├────────────┤
│ id           │  │ id         │
│ note_id      │  │ source_note_id │
│ user_id      │  │ target_note_id │ (unique)
│ role         │  └────────────┘
└──────────────┘
```

### Key Relationships:

- **users** ↔ **notes**: One-to-many (owner)
- **notes** ↔ **versions**: One-to-many + one-to-one (head_version)
- **notes** ↔ **collaborators**: One-to-many
- **notes** ↔ **forks**: One-to-many (source), one-to-one (target)
- **versions**: Self-referential (parent_version)

### Key Constraints:

- `versions.content` is **immutable** after creation
- `notes.head_version_id` always points to the most recent version
- `forks.target_note_id` is unique (one fork per target)
- `collaborators` has unique constraint on (note_id, user_id)

## 🔌 API Endpoints

Base URL: `http://localhost:3000/api/v1`

### Authentication

All endpoints require HTTP Basic Authentication:
```
Authorization: Basic <base64(email:password)>
```

Sample users (from `db/seeds.rb`):
- `alice@example.com` / `password123`
- `bob@example.com` / `password123`
- `charlie@example.com` / `password123`

### Notes

```http
# List notes (filtered by permissions)
GET /api/v1/notes
Query params: page, per_page
Headers: X-Total-Count

# Create note
POST /api/v1/notes
Body: { "note": { "title": "...", "visibility": "private" } }

# Show note
GET /api/v1/notes/:id

# Update note (title/visibility only, owner only)
PATCH /api/v1/notes/:id
Body: { "note": { "title": "...", "visibility": "..." } }

# Delete note (owner only)
DELETE /api/v1/notes/:id

# Fork note
POST /api/v1/notes/:id/fork
```

### Versions

```http
# List versions for a note (newest first)
GET /api/v1/notes/:note_id/versions
Query params: page, per_page

# Show specific version
GET /api/v1/notes/:note_id/versions/:id

# Create new version (owner or editor)
POST /api/v1/notes/:note_id/versions
Body: {
  "version": {
    "content": "...",
    "summary": "...",
    "base_version_id": 123  # Optional: for conflict detection
  }
}

# Revert to a version (creates new version, owner or editor)
POST /api/v1/notes/:note_id/versions/:id/revert
Body: { "version": { "summary": "..." } }  # Optional
```

### Collaborators

```http
# List collaborators (anyone with view access)
GET /api/v1/notes/:note_id/collaborators

# Add collaborator (owner only)
POST /api/v1/notes/:note_id/collaborators
Body: { "collaborator": { "user_id": 2, "role": "editor" } }

# Remove collaborator (owner only)
DELETE /api/v1/notes/:note_id/collaborators/:id
```

### Response Format

**Success (200/201):**
```json
{
  "id": 1,
  "title": "Note Title",
  ...
}
```

**Error (4xx/5xx):**
```json
{
  "error": {
    "code": "not_found|forbidden|validation_failed|version_conflict",
    "message": "Human-readable message",
    "details": {}  // Optional, for validation errors
  }
}
```

**Status Codes:**
- `200 OK`: Success
- `201 Created`: Resource created
- `204 No Content`: Deleted
- `403 Forbidden`: Authorization failed
- `404 Not Found`: Resource not found
- `409 Conflict`: Version conflict (base_version_id mismatch)
- `422 Unprocessable Entity`: Validation failed

## 🏗️ Architecture

### Domain Models

- **User**: Devise authentication, owns notes
- **Note**: Container for versions, has visibility settings
- **Version**: Immutable content snapshot with parent linkage
- **Collaborator**: Join table with role (viewer/editor)
- **Fork**: Tracks note derivation relationships

### Service Objects

All persistence operations use service objects with transactions:

- **Versions::Create**: Creates version + updates head atomically + broadcasts real-time events
- **Versions::Revert**: Copies content from target version + broadcasts
- **Notes::Fork**: Duplicates note with new owner
- **Presence::Manager**: Manages real-time user presence per note
- **Diffs::Compute**: Placeholder for future diff logic

### Real-time Collaboration (Action Cable)

WebSocket-based live collaboration features:

- **NotesChannel**: Subscribe to note-specific updates (requires show permission)
- **Presence Tracking**: See who's actively viewing/editing in real time
- **Version Updates**: Automatic history refresh when collaborators save
- **Typing Indicators**: See when collaborators are actively typing (editors only)
- **Conflict Alerts**: Real-time notifications when base version mismatches

**Event Contracts:**
- `version_created`: Broadcast when new version saved
- `presence`: Active user list with initials
- `typing`: Ephemeral typing signal (3-5s display)
- `conflict_notice`: Head/base mismatch detected

**Security:**
- Token-based WebSocket auth via query params
- Pundit policies enforce subscribe permissions
- Typing restricted to editors/owners

### Authorization (Pundit)

- **NotePolicy**: Owner, collaborator, and visibility-based access
- **VersionPolicy**: Delegates to note policy
- **CollaboratorPolicy**: Owner-only management
- **ForkPolicy**: Can fork any viewable note

### Key Principles (CLAUDE.md)

1. **Append-Only Versions**: Reverts create new versions, never modify history
2. **Transactional Updates**: Version creation + head update in single transaction
3. **Conflict Detection**: `base_version_id` parameter for concurrent edit handling
4. **Permission Validation**: All persistence methods check authorization
5. **N+1 Prevention**: Eager loading in controllers
6. **100% Test Coverage**: All public persistence methods have RSpec specs

## 📁 Project Structure

```
app/
├── channels/                        # Action Cable (WebSockets)
│   ├── application_cable/
│   │   ├── connection.rb            # WebSocket auth
│   │   └── channel.rb
│   └── notes_channel.rb             # Real-time note updates
├── controllers/
│   ├── application_controller.rb    # Pundit + Devise integration
│   ├── concerns/
│   │   └── api_error_handler.rb     # Standardized error responses
│   └── api/v1/                      # API endpoints
│       ├── notes_controller.rb
│       ├── versions_controller.rb
│       └── collaborators_controller.rb
├── models/
│   ├── user.rb                      # Devise user
│   ├── note.rb                      # Note with visibility enum
│   ├── version.rb                   # Immutable version
│   ├── collaborator.rb              # Role-based access
│   └── fork.rb                      # Fork tracking
├── policies/                        # Pundit authorization
│   ├── application_policy.rb
│   ├── note_policy.rb
│   ├── version_policy.rb
│   ├── collaborator_policy.rb
│   └── fork_policy.rb
└── services/                        # Business logic
    ├── versions/
    │   ├── create.rb                # + broadcasts version_created
    │   └── revert.rb                # + broadcasts version_created
    ├── presence/
    │   └── manager.rb               # User presence tracking
    ├── notes/
    │   └── fork.rb
    └── diffs/
        └── compute.rb

spec/                                # RSpec tests (500+ specs)
├── channels/                        # Action Cable channel tests
├── models/
├── services/
├── policies/
├── requests/
└── factories/
```

## 🔧 Configuration

### Environment Variables

Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

### Database Configuration

PostgreSQL runs in Docker (`docker-compose.yml`):
- Port: 5432
- Username: postgres
- Password: postgres

Configuration in `config/database.yml`.

## 🐳 Docker Setup

### PostgreSQL Only (Recommended for Development)

```bash
# Start PostgreSQL
docker-compose up -d postgres

# Stop PostgreSQL
docker-compose down

# View logs
docker-compose logs -f postgres
```

### Full Stack in Docker (Optional)

Uncomment the `web` service in `docker-compose.yml`, then:

```bash
docker-compose up
```

## 📝 Sample Data

Run `rails db:seed` to create:

- **3 users**: Alice, Bob, Charlie
- **5 notes** with varying visibility
- **10 versions** demonstrating version chains and reverts
- **3 collaborators** with different roles
- **1 fork** relationship

## 🎯 Acceptance Criteria (Met)

✅ Authenticated user can create notes and versions
✅ First version bootstraps with nil parent, subsequent have parent linkage
✅ Head version advances atomically with version creation
✅ Revert creates new version with copied content
✅ Fork creates independent note with new owner
✅ Collaborators can be added/removed (owner only)
✅ Permissions enforced across all endpoints
✅ Unauthorized access returns 403 with standard error format
✅ All specs pass locally
✅ Seeds load successfully

## 🚧 Out of Scope (Backend - Future PRs)

- Real-time Action Cable for presence and conflict alerts
- Full diff computation and merge service logic
- Azure AI Search integration for semantic search
- Rate limiting and advanced performance tuning
- JWT token authentication

---

## 🎨 Frontend (Next.js)

The frontend is a Next.js 14 application with TypeScript, providing a polished UI for the versioned notes system.

### Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS + shadcn/ui components
- **State Management**: TanStack Query (React Query v5)
- **Rich Text**: TipTap editor with markdown shortcuts
- **Animation**: Framer Motion
- **Validation**: Zod schemas
- **Testing**: Vitest (unit) + Playwright (E2E)

### Quick Start

```bash
cd frontend
npm install
cp .env.local.example .env.local
npm run dev
```

Frontend runs on **http://localhost:3001**

### Environment Variables

```env
NEXT_PUBLIC_APP_NAME=Versioned Notes
BACKEND_BASE_URL=http://localhost:3000/api/v1
NEXT_PUBLIC_BACKEND_WS_URL=ws://localhost:3000/cable
BACKEND_WS_URL=ws://localhost:3000/cable
SESSION_COOKIE_NAME=vn_auth
SESSION_COOKIE_SECURE=false  # true in production
```

### Features Implemented

✅ **Authentication**
- Login page with credential validation
- Server-side session via HttpOnly cookies
- Auth token stored as `base64(email:password)`
- All API requests include `Authorization: Basic` header

✅ **Dashboard**
- List accessible notes with pagination
- Create new notes
- Search bar placeholder (non-functional)
- Visibility badges (Private, Link, Public)
- Empty state with call-to-action

✅ **Note Editor**
- TipTap rich text editor with markdown shortcuts
- Save version with conflict detection (409 handling)
- Keyboard shortcut: Cmd/Ctrl+S to save
- Version history pane (paginated)
- Real-time content change detection

✅ **Real-time Collaboration**
- Live presence bar showing active collaborators
- Typing indicators for concurrent editors
- Automatic version history updates
- Conflict notifications with Fork/Refresh options
- WebSocket connection via Action Cable

✅ **UI/UX**
- Light/dark theme toggle with system preference
- Responsive layout (desktop optimized, mobile functional)
- Loading states with skeleton screens
- Error states with retry actions
- Accessible keyboard navigation

### Authentication Flow

**Security Model:**
1. User enters email/password on login page
2. Next.js server creates HttpOnly cookie with `base64(email:password)`
3. Cookie is SameSite=Lax, Secure in production
4. All backend requests from Next.js include `Authorization: Basic <token>`
5. Credentials **never** exposed to client JavaScript

**⚠️ Important:** This is a bootstrap approach for development. In production, replace with:
- JWT tokens from Devise
- OAuth2/OpenID Connect
- Session tokens with CSRF protection

### File Structure

```
frontend/
├── app/
│   ├── layout.tsx                    # Root layout with providers
│   ├── page.tsx                      # Dashboard (notes list)
│   ├── auth/login/page.tsx           # Login page
│   ├── notes/[id]/page.tsx           # Note editor + history
│   └── api/
│       ├── auth/                     # Auth endpoints
│       └── notes/                    # Notes/versions proxies
├── components/
│   ├── ui/                           # shadcn components
│   ├── layout/                       # Header, etc.
│   ├── editor/                       # TipTap editor
│   └── feedback/                     # Loading, error, empty states
├── lib/
│   ├── api/                          # API client + Zod schemas
│   ├── auth/                         # Session management
│   ├── realtime/                     # Action Cable client
│   │   ├── cable.ts                  # Consumer with reconnection
│   │   ├── notes.ts                  # Note subscription manager
│   │   └── types.ts                  # Event type definitions
│   ├── hooks/                        # React hooks
│   │   ├── use-toast.ts
│   │   └── use-realtime-note.ts      # Real-time collaboration hook
│   ├── providers/                    # React Query, theme providers
│   └── utils.ts                      # Utility functions
└── test/
    ├── unit/                         # Vitest tests
    └── e2e/                          # Playwright tests (incl. real-time)
```

### Known Limitations (Out of Scope)

❌ Real-time collaboration (Action Cable integration)
❌ Diff view for version comparison
❌ Merge conflict resolution UI
❌ Azure AI Search integration
❌ Command palette wiring
❌ Full accessibility audit (WCAG AA)
❌ Production-ready auth (JWT/OAuth)

See [`frontend/IMPLEMENTATION_GUIDE.md`](frontend/IMPLEMENTATION_GUIDE.md) for detailed completion steps.

### Testing

```bash
# Unit tests (Vitest)
npm test

# E2E tests (Playwright)
npm run test:e2e

# Type checking
npm run type-check

# Linting
npm run lint
```

### Demo Credentials

```
Email: alice@example.com
Password: password123
```

---

## 📖 Additional Documentation

- **CLAUDE.md**: Domain rules and project constraints
- **.claude-on-rails/prompts/**: Specialized agent prompts for different layers
- **Devise docs**: https://github.com/heartcombo/devise
- **Pundit docs**: https://github.com/varvet/pundit
- **Kaminari docs**: https://github.com/kaminari/kaminari

## 🤝 Contributing

This is a foundation PR establishing the core versioning system. Future contributions should:

1. Maintain append-only version semantics
2. Use transactional services for all persistence
3. Add comprehensive RSpec coverage
4. Follow Pundit authorization patterns
5. Adhere to CLAUDE.md constraints

## 📄 License

[Your License Here]
