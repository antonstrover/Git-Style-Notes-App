# Versioned Notes Frontend

A Next.js 14 application providing a polished UI for collaborative, version-controlled note-taking.

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Copy environment template
cp .env.local.example .env.local

# Start development server
npm run dev
```

Frontend runs on **http://localhost:3001**

Backend must be running on **http://localhost:3000** (see `../README.md`)

## 📋 Prerequisites

- Node.js 18+ or 20+
- npm or pnpm
- Rails backend running (see root README)

## 🔧 Environment Setup

Edit `.env.local`:

```env
NEXT_PUBLIC_APP_NAME=Versioned Notes
BACKEND_BASE_URL=http://localhost:3000/api/v1
SESSION_COOKIE_NAME=vn_auth
SESSION_COOKIE_SECURE=false
```

Set `SESSION_COOKIE_SECURE=true` in production.

## 🎯 Features

### ✅ Implemented
- **Auth**: Login with HTTP Basic (server-side cookies)
- **Dashboard**: List notes, create notes, pagination
- **Editor**: TipTap rich text editor with markdown support
- **Versions**: History pane with paginated version list
- **Conflict Detection**: Handles 409 conflicts from concurrent edits
- **Theme**: Light/dark mode toggle
- **Keyboard Shortcuts**: Cmd/Ctrl+S to save

### ⬜ Remaining (See IMPLEMENTATION_GUIDE.md)
- Additional UI components (Dialog, Toast, DropdownMenu, Tabs)
- Conflict resolution dialog
- Toast notifications
- Update note title functionality
- Comprehensive testing (unit + E2E)
- Accessibility enhancements
- Mobile responsive refinements

## 🏗️ Architecture

### Tech Stack
- **Next.js 14** (App Router, React Server Components)
- **TypeScript** (strict mode)
- **Tailwind CSS** + **shadcn/ui** (component library)
- **TanStack Query v5** (server state management)
- **TipTap** (rich text editor)
- **Zod** (schema validation)
- **Framer Motion** (animations)
- **Vitest** + **Playwright** (testing)

### Authentication Flow

```
┌──────────┐           ┌──────────┐           ┌──────────┐
│  Login   │  POST     │  Next.js │  Basic    │  Rails   │
│   Page   ├──────────►│  Server  ├──────────►│  Backend │
└──────────┘           └─────┬────┘           └──────────┘
                             │
                    HttpOnly Cookie
                  (base64(email:password))
                             │
                             ▼
                    ┌────────────────┐
                    │ Client Browser │
                    │ (no cred access)│
                    └────────────────┘
```

**Security:**
- Credentials stored in HttpOnly cookie (inaccessible to JavaScript)
- SameSite=Lax (CSRF mitigation)
- Secure flag in production (HTTPS only)
- Server-side auth header injection for all API requests

**⚠️ Temporary Approach:** Replace with JWT/Devise sessions before production.

### Directory Structure

```
frontend/
├── app/
│   ├── layout.tsx                    # Root layout + providers
│   ├── page.tsx                      # Dashboard
│   ├── globals.css                   # Global styles + TipTap CSS
│   ├── auth/login/page.tsx           # Login page
│   ├── notes/[id]/page.tsx           # Note editor + history
│   └── api/                          # Next.js API routes (proxy to Rails)
│       ├── auth/                     # Login, logout, session validation
│       └── notes/                    # Notes & versions endpoints
│
├── components/
│   ├── ui/                           # shadcn/ui primitives
│   │   ├── button.tsx
│   │   ├── input.tsx
│   │   ├── card.tsx
│   │   ├── badge.tsx
│   │   └── ...
│   ├── layout/
│   │   └── header.tsx                # App header with theme toggle
│   ├── editor/
│   │   └── tiptap-editor.tsx         # TipTap wrapper component
│   └── feedback/
│       ├── loading-state.tsx         # Skeleton screens
│       ├── error-state.tsx           # Error UI with retry
│       └── empty-state.tsx           # Empty states with CTAs
│
├── lib/
│   ├── api/
│   │   ├── http.ts                   # Fetch wrapper with auth
│   │   ├── schemas.ts                # Zod validation schemas
│   │   ├── keys.ts                   # TanStack Query key factories
│   │   └── notes.ts                  # API functions (listNotes, createNote, etc.)
│   ├── auth/
│   │   └── session.ts                # Server-side session helpers
│   ├── providers/
│   │   ├── query-provider.tsx        # TanStack Query setup
│   │   └── theme-provider.tsx        # next-themes wrapper
│   ├── types/
│   │   └── index.ts                  # TypeScript types
│   └── utils.ts                      # Utility functions (cn, formatDate)
│
├── test/
│   ├── setup.ts                      # Vitest config
│   ├── unit/                         # Component tests
│   └── e2e/                          # Playwright tests
│
├── next.config.ts
├── tailwind.config.ts
├── tsconfig.json
├── vitest.config.ts
├── playwright.config.ts
└── IMPLEMENTATION_GUIDE.md           # Detailed completion steps
```

## 🧪 Testing

```bash
# Run unit tests (Vitest)
npm test

# Run E2E tests (Playwright)
npm run test:e2e

# E2E with UI
npm run test:e2e:ui

# Type checking
npm run type-check

# Linting
npm run lint
```

## 🔐 Demo Credentials

From Rails `db/seeds.rb`:

```
Email: alice@example.com
Password: password123
```

Other users: `bob@example.com`, `charlie@example.com` (same password).

## 📦 Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server (port 3001) |
| `npm run build` | Build for production |
| `npm run start` | Start production server |
| `npm run lint` | Run ESLint |
| `npm test` | Run unit tests |
| `npm run test:e2e` | Run E2E tests |
| `npm run type-check` | TypeScript type checking |

## 🚧 Known Issues & Limitations

1. **Auth Security**: Basic auth with cookie storage is a temporary bootstrap. Replace before production.
2. **No Real-Time**: Action Cable not integrated yet.
3. **Limited Mobile UX**: Desktop-first design; mobile needs polish.
4. **No Diff View**: Version comparison not implemented.
5. **Search Disabled**: Placeholder only; Azure Search integration pending.

See `IMPLEMENTATION_GUIDE.md` for completion roadmap.

## 📚 Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `next` | ^14.2.0 | React framework |
| `react` | ^18.3.0 | UI library |
| `@tanstack/react-query` | ^5.60.0 | Server state management |
| `@tiptap/react` | ^2.10.0 | Rich text editor |
| `zod` | ^3.24.0 | Schema validation |
| `tailwindcss` | ^3.4.0 | CSS framework |
| `lucide-react` | ^0.460.0 | Icon library |
| `framer-motion` | ^11.15.0 | Animation library |
| `vitest` | ^2.1.8 | Unit testing |
| `@playwright/test` | ^1.49.0 | E2E testing |

## 🤝 Contributing

When adding features:
1. Follow existing file structure conventions
2. Use Zod schemas for API validation
3. Add loading/error states for async operations
4. Include TypeScript types (no `any`)
5. Test with both light and dark themes
6. Ensure keyboard accessibility

## 📖 Additional Resources

- **Implementation Guide**: `IMPLEMENTATION_GUIDE.md`
- **Root README**: `../README.md`
- **Backend Documentation**: `../README.md#api-endpoints`
- **Next.js Docs**: https://nextjs.org/docs
- **TanStack Query**: https://tanstack.com/query/latest
- **shadcn/ui**: https://ui.shadcn.com/
- **TipTap**: https://tiptap.dev/

## 📄 License

[Your License Here]
