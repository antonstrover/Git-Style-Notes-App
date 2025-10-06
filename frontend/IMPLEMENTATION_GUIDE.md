# Frontend Implementation Guide

This document outlines the current state of the Next.js frontend implementation and provides guidance for completing the remaining components.

## ✅ Completed Components

### 1. Project Bootstrap & Configuration
- ✅ Next.js 14 with TypeScript, app router
- ✅ Tailwind CSS with custom theme tokens
- ✅ ESLint, Prettier configuration
- ✅ Vitest & Playwright setup
- ✅ Environment configuration (`.env.local.example`)

### 2. Auth Bridge (Server-Side Cookies)
- ✅ `lib/auth/session.ts` - Session management helpers
- ✅ `app/api/auth/login/route.ts` - Login endpoint
- ✅ `app/api/auth/logout/route.ts` - Logout endpoint
- ✅ `app/api/auth/me/route.ts` - Session validation
- ✅ `app/auth/login/page.tsx` - Login page with form

### 3. API Client Layer
- ✅ `lib/api/http.ts` - Server fetch with auth headers
- ✅ `lib/api/schemas.ts` - Zod schemas for validation
- ✅ `lib/api/keys.ts` - TanStack Query key factories
- ✅ `lib/api/notes.ts` - API functions for notes & versions

### 4. App Shell & Layout
- ✅ `app/layout.tsx` - Root layout with providers
- ✅ `lib/providers/query-provider.tsx` - TanStack Query provider
- ✅ `lib/providers/theme-provider.tsx` - Theme provider
- ✅ `components/layout/header.tsx` - Header with theme toggle & logout

### 5. UI Building Blocks (Partial)
- ✅ `components/ui/button.tsx`
- ✅ `components/ui/input.tsx`
- ✅ `components/ui/label.tsx`
- ✅ `components/ui/card.tsx`
- ✅ `components/ui/badge.tsx`
- ✅ `components/ui/skeleton.tsx`
- ✅ `components/ui/visibility-badge.tsx`
- ✅ `components/feedback/loading-state.tsx`
- ✅ `components/feedback/error-state.tsx`
- ✅ `components/feedback/empty-state.tsx`

### 6. Dashboard Page
- ✅ `app/page.tsx` - Notes list with create action
- ✅ `app/api/notes/route.ts` - GET (list) & POST (create) endpoints
- ✅ Pagination controls
- ✅ Empty state with call-to-action

### 7. Note View Page
- ✅ `app/notes/[id]/page.tsx` - Editor + History pane
- ✅ `components/editor/tiptap-editor.tsx` - Rich text editor
- ✅ `app/api/notes/[id]/route.ts` - GET note detail
- ✅ `app/api/notes/[id]/versions/route.ts` - GET/POST versions
- ✅ Conflict detection (409 handling)
- ✅ Keyboard shortcut (Cmd/Ctrl+S)

---

## 🚧 Remaining Implementation

### 1. Additional UI Components

Create the following shadcn/ui components:

#### `components/ui/dialog.tsx`
```tsx
import * as DialogPrimitive from "@radix-ui/react-dialog";
// Standard shadcn dialog implementation
```

#### `components/ui/toast.tsx` & `components/ui/use-toast.ts`
```tsx
import * as ToastPrimitive from "@radix-ui/react-toast";
// Toast notification system for success/error feedback
```

#### `components/ui/dropdown-menu.tsx`
```tsx
import * as DropdownMenuPrimitive from "@radix-ui/react-dropdown-menu";
// For user menu and context menus
```

#### `components/ui/tabs.tsx`
```tsx
import * as TabsPrimitive from "@radix-ui/react-tabs";
// For responsive History pane (mobile view)
```

#### `components/ui/scroll-area.tsx`
```tsx
import * as ScrollAreaPrimitive from "@radix-ui/react-scroll-area";
// For scrollable history pane
```

#### `components/ui/separator.tsx`
```tsx
import * as SeparatorPrimitive from "@radix-ui/react-separator";
// For visual separation
```

#### `components/ui/tooltip.tsx`
```tsx
import * as TooltipPrimitive from "@radix-ui/react-tooltip";
// For button tooltips
```

**Reference**: Use the [shadcn/ui documentation](https://ui.shadcn.com/) for implementation patterns.

---

### 2. Conflict Dialog

Create a dedicated dialog component for handling 409 conflicts:

#### `components/editor/conflict-dialog.tsx`
```tsx
"use client";

import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";

interface ConflictDialogProps {
  open: boolean;
  onClose: () => void;
  onRefresh: () => void;
}

export function ConflictDialog({ open, onClose, onRefresh }: ConflictDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent>
        <DialogHeader>
          <div className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5 text-destructive" />
            <DialogTitle>Version Conflict</DialogTitle>
          </div>
          <DialogDescription>
            The note has been updated by someone else while you were editing.
            Your changes cannot be saved. Please refresh to see the latest version.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={onRefresh}>
            Refresh Content
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
```

Then update `app/notes/[id]/page.tsx` to use this dialog when detecting a 409 error.

---

### 3. Toast Notifications

Add toast notifications for success/error feedback:

#### `app/layout.tsx` (update)
```tsx
import { Toaster } from "@/components/ui/toaster";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          <QueryProvider>
            <div className="flex min-h-screen flex-col">
              <Header />
              <main className="flex-1">{children}</main>
            </div>
            <Toaster />
          </QueryProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
```

#### Usage in pages
```tsx
import { useToast } from "@/components/ui/use-toast";

const { toast } = useToast();

// On success
toast({
  title: "Version saved",
  description: "Your changes have been saved successfully.",
});

// On error
toast({
  title: "Error",
  description: error.message,
  variant: "destructive",
});
```

---

### 4. Testing

#### Unit Tests (`test/unit/`)

Create tests for key components:

**`test/unit/dashboard.test.tsx`**
```tsx
import { render, screen } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import DashboardPage from "@/app/page";

describe("Dashboard", () => {
  it("renders empty state when no notes", () => {
    const queryClient = new QueryClient();
    render(
      <QueryClientProvider client={queryClient}>
        <DashboardPage />
      </QueryClientProvider>
    );
    expect(screen.getByText(/No notes yet/i)).toBeInTheDocument();
  });
});
```

**`test/unit/tiptap-editor.test.tsx`**
```tsx
import { render, screen } from "@testing-library/react";
import { TipTapEditor } from "@/components/editor/tiptap-editor";

describe("TipTapEditor", () => {
  it("renders with placeholder", () => {
    render(
      <TipTapEditor
        content=""
        onContentChange={() => {}}
        placeholder="Test placeholder"
      />
    );
    expect(screen.getByText(/Test placeholder/i)).toBeInTheDocument();
  });
});
```

#### E2E Tests (`test/e2e/`)

**`test/e2e/auth.spec.ts`**
```typescript
import { test, expect } from "@playwright/test";

test("login flow", async ({ page }) => {
  await page.goto("/auth/login");
  await page.fill('input[type="email"]', "alice@example.com");
  await page.fill('input[type="password"]', "password123");
  await page.click('button[type="submit"]');
  await expect(page).toHaveURL("/");
});
```

**`test/e2e/notes.spec.ts`**
```typescript
import { test, expect } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  // Login
  await page.goto("/auth/login");
  await page.fill('input[type="email"]', "alice@example.com");
  await page.fill('input[type="password"]', "password123");
  await page.click('button[type="submit"]');
  await page.waitForURL("/");
});

test("create and save note", async ({ page }) => {
  await page.click("text=New Note");
  await page.waitForURL(/\/notes\/\d+/);

  // Type content
  await page.fill(".ProseMirror", "Test content");

  // Save
  await page.click("text=Save Version");
  await expect(page.locator("text=Version saved")).toBeVisible();
});

test("conflict detection", async ({ page, context }) => {
  // Open note in two tabs, simulate conflict
  // ... implementation
});
```

---

### 5. Accessibility Enhancements

- ✅ Keyboard navigation (Cmd/Ctrl+S implemented)
- ⬜ ARIA labels on all interactive elements
- ⬜ Focus management for dialogs
- ⬜ Announce toast notifications to screen readers

Update components to include proper `aria-label` attributes:

```tsx
<Button aria-label="Create new note" onClick={...}>
  <Plus className="mr-2 h-4 w-4" />
  New Note
</Button>
```

---

### 6. Responsive Design

The current implementation is partially responsive. Enhance mobile experience:

#### `app/notes/[id]/page.tsx` (update grid)
```tsx
<div className="grid gap-6 lg:grid-cols-[1fr_400px]">
  {/* Editor */}
  <div className="space-y-4">...</div>

  {/* History - use Tabs on mobile */}
  <div className="lg:block">
    <Tabs defaultValue="history" className="lg:hidden">
      <TabsList>
        <TabsTrigger value="editor">Editor</TabsTrigger>
        <TabsTrigger value="history">History</TabsTrigger>
      </TabsList>
      <TabsContent value="history">
        {/* History component */}
      </TabsContent>
    </Tabs>

    <div className="hidden lg:block">
      {/* Desktop history pane */}
    </div>
  </div>
</div>
```

---

### 7. Missing API Routes

The following features need API routes:

#### Update Note Title
**`app/api/notes/[id]/route.ts`** (add PATCH)
```tsx
export async function PATCH(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  const params = await context.params;
  const noteId = parseInt(params.id, 10);
  const body = await request.json();

  const updatedNote = await updateNote(noteId, body.note);
  return NextResponse.json(updatedNote);
}
```

---

## 📦 Installation & Setup

1. **Install dependencies**
   ```bash
   cd frontend
   npm install
   ```

2. **Configure environment**
   ```bash
   cp .env.local.example .env.local
   # Edit .env.local with your backend URL
   ```

3. **Run development server**
   ```bash
   npm run dev
   ```
   Frontend runs on http://localhost:3001

4. **Run tests**
   ```bash
   npm test              # Unit tests
   npm run test:e2e     # E2E tests
   ```

---

## 🔒 Security Notes

**Current Implementation:**
- HttpOnly cookies store `base64(email:password)`
- Server-side only - never exposed to client JS
- SameSite=Lax, Secure in production

**Limitations:**
- This is a bootstrap approach
- **TODO**: Replace with JWT or Devise token sessions in production
- No CSRF protection yet (add `csrf_token` validation later)

---

## 📝 Next Steps Priority

1. **High Priority**
   - Add Dialog component & Conflict Dialog
   - Implement Toast notifications
   - Add update note title functionality

2. **Medium Priority**
   - Complete UI component library
   - Write unit tests for Dashboard & Editor
   - Add E2E smoke tests

3. **Low Priority (Future PRs)**
   - Real-time Action Cable integration
   - Diff view for version comparison
   - Merge/conflict resolution UX
   - Command palette
   - Azure AI Search integration

---

## 📚 References

- [Next.js App Router](https://nextjs.org/docs/app)
- [TanStack Query](https://tanstack.com/query/latest)
- [shadcn/ui](https://ui.shadcn.com/)
- [TipTap Editor](https://tiptap.dev/)
- [Radix UI](https://www.radix-ui.com/)
