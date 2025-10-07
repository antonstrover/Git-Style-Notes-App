import { test, expect } from "@playwright/test";

test.describe("Real-time Collaboration", () => {
  test.beforeEach(async ({ page }) => {
    // Login as alice
    await page.goto("/auth/login");
    await page.fill('input[type="email"]', "alice@example.com");
    await page.fill('input[type="password"]', "password123");
    await page.click('button[type="submit"]');
    await page.waitForURL("/");
  });

  test("presence bar shows active collaborators", async ({ page, context }) => {
    // Create a new note
    await page.click('button:has-text("New Note")');
    await page.waitForURL(/\/notes\/(\d+)/);
    const noteUrl = page.url();

    // Wait for presence connection
    await page.waitForTimeout(1000);

    // Alice should see herself in presence
    await expect(page.locator('text=/Active:/i')).toBeVisible({ timeout: 5000 });

    // Open same note as Bob in new context
    const bobContext = await context.browser()?.newContext();
    if (!bobContext) throw new Error("Could not create bob context");
    const bobPage = await bobContext.newPage();

    // Login as bob
    await bobPage.goto("/auth/login");
    await bobPage.fill('input[type="email"]', "bob@example.com");
    await bobPage.fill('input[type="password"]', "password123");
    await bobPage.click('button[type="submit"]');
    await bobPage.waitForURL("/");

    // Bob navigates to the same note
    await bobPage.goto(noteUrl);
    await bobPage.waitForTimeout(1000);

    // Both should see presence count of 2
    await expect(page.locator('text=/(2)/i')).toBeVisible({ timeout: 5000 });
    await expect(bobPage.locator('text=/(2)/i')).toBeVisible({ timeout: 5000 });

    // Clean up
    await bobContext.close();
  });

  test("version history updates automatically", async ({ page, context }) => {
    // Create a new note
    await page.click('button:has-text("New Note")');
    await page.waitForURL(/\/notes\/(\d+)/);
    const noteUrl = page.url();

    // Type content and save
    const editor = page.locator(".ProseMirror");
    await editor.click();
    await editor.fill("Initial content from Alice");
    await page.click('button:has-text("Save Version")');
    await expect(page.locator("text=Version saved")).toBeVisible({ timeout: 5000 });

    // Open same note as Bob
    const bobContext = await context.browser()?.newContext();
    if (!bobContext) throw new Error("Could not create bob context");
    const bobPage = await bobContext.newPage();

    await bobPage.goto("/auth/login");
    await bobPage.fill('input[type="email"]', "bob@example.com");
    await bobPage.fill('input[type="password"]', "password123");
    await bobPage.click('button[type="submit"]');
    await bobPage.waitForURL("/");
    await bobPage.goto(noteUrl);
    await bobPage.waitForTimeout(1000);

    // Bob edits and saves
    const bobEditor = bobPage.locator(".ProseMirror");
    await bobEditor.click();
    await bobEditor.fill("Updated by Bob");
    await bobPage.click('button:has-text("Save Version")');
    await expect(bobPage.locator("text=Version saved")).toBeVisible({ timeout: 5000 });

    // Alice should see toast notification about Bob's update
    await expect(page.locator("text=Note updated")).toBeVisible({ timeout: 5000 });

    // Clean up
    await bobContext.close();
  });

  test("typing indicator appears", async ({ page, context }) => {
    // Create a new note and add Bob as editor
    await page.click('button:has-text("New Note")');
    await page.waitForURL(/\/notes\/(\d+)/);
    const noteUrl = page.url();
    const noteId = noteUrl.match(/\/notes\/(\d+)/)?.[1];

    // Add Bob as collaborator (would need API or UI to do this)
    // For now, this test assumes Bob has editor rights via seed data

    // Open as Bob
    const bobContext = await context.browser()?.newContext();
    if (!bobContext) throw new Error("Could not create bob context");
    const bobPage = await bobContext.newPage();

    await bobPage.goto("/auth/login");
    await bobPage.fill('input[type="email"]', "bob@example.com");
    await bobPage.fill('input[type="password"]', "password123");
    await bobPage.click('button[type="submit"]');
    await bobPage.waitForURL("/");
    await bobPage.goto(noteUrl);
    await bobPage.waitForTimeout(1000);

    // Bob starts typing
    const bobEditor = bobPage.locator(".ProseMirror");
    await bobEditor.click();
    await bobEditor.type("Bob is typing");

    // Alice should see typing indicator
    await expect(page.locator('text=/is typing/i')).toBeVisible({ timeout: 5000 });

    // Clean up
    await bobContext.close();
  });

  test("conflict dialog appears on concurrent edits", async ({ page, context }) => {
    // Create a note
    await page.click('button:has-text("New Note")');
    await page.waitForURL(/\/notes\/(\d+)/);
    const noteUrl = page.url();

    // Alice types content
    const aliceEditor = page.locator(".ProseMirror");
    await aliceEditor.click();
    await aliceEditor.fill("Alice's content");

    // Open as Bob and edit
    const bobContext = await context.browser()?.newContext();
    if (!bobContext) throw new Error("Could not create bob context");
    const bobPage = await bobContext.newPage();

    await bobPage.goto("/auth/login");
    await bobPage.fill('input[type="email"]', "bob@example.com");
    await bobPage.fill('input[type="password"]', "password123");
    await bobPage.click('button[type="submit"]');
    await bobPage.waitForURL("/");
    await bobPage.goto(noteUrl);

    // Bob edits and saves first
    const bobEditor = bobPage.locator(".ProseMirror");
    await bobEditor.click();
    await bobEditor.fill("Bob's content - saved first");
    await bobPage.click('button:has-text("Save Version")');
    await expect(bobPage.locator("text=Version saved")).toBeVisible({ timeout: 5000 });

    // Alice tries to save (should get conflict)
    await page.click('button:has-text("Save Version")');
    await expect(page.locator("text=Version Conflict")).toBeVisible({ timeout: 5000 });

    // Dialog should have Fork and Refresh buttons
    await expect(page.locator('button:has-text("Fork Note")')).toBeVisible();
    await expect(page.locator('button:has-text("Refresh Content")')).toBeVisible();

    // Clean up
    await bobContext.close();
  });
});
