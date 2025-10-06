# Versioned Notes Backend

A Rails 8 API-only application providing immutable, versioned note-taking with collaborative features. Built with append-only version history, transactional consistency, and comprehensive authorization.

## 🎯 Features

- **Immutable Versioning**: Append-only version history with atomic head pointer updates
- **Collaborative Editing**: Role-based access control (owner/editor/viewer)
- **Note Forking**: Create independent copies of notes with full version history
- **Conflict Detection**: Base version ID checking for concurrent edits
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

- **Versions::Create**: Creates version + updates head atomically
- **Versions::Revert**: Copies content from target version
- **Notes::Fork**: Duplicates note with new owner
- **Diffs::Compute**: Placeholder for future diff logic

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
    │   ├── create.rb
    │   └── revert.rb
    ├── notes/
    │   └── fork.rb
    └── diffs/
        └── compute.rb

spec/                                # RSpec tests (450+ specs)
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

## 🚧 Out of Scope (Future PRs)

- Real-time Action Cable for presence and conflict alerts
- Full diff computation and merge service logic
- Azure AI Search integration for semantic search
- Rate limiting and advanced performance tuning
- Frontend/SDK clients
- JWT token authentication

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
