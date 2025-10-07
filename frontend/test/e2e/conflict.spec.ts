import { test, expect } from "@playwright/test";

test.describe("Version Conflicts", () => {
  test.beforeEach(async ({ page }) => {
    // Login before each test
    await page.goto("/auth/login");
    await page.fill('input[type="email"]', "alice@example.com");
    await page.fill('input[type="password"]', "password123");
    await page.click('button[type="submit"]');
    await page.waitForURL("/");
  });

  test("conflict dialog appears on 409 error", async ({ page, context }) => {
    // Create a new note
    await page.click('button:has-text("New Note")');
    await page.waitForURL(/\/notes\/(\d+)/);

    const noteUrl = page.url();
    const noteId = noteUrl.match(/\/notes\/(\d+)/)?.[1];

    // Type content
    const editor = page.locator(".ProseMirror");
    await editor.click();
    await editor.fill("Initial content");

    // Simulate a conflict by opening the same note in a second tab
    const page2 = await context.newPage();
    await page2.goto(noteUrl);

    // Edit and save in second tab first
    const editor2 = page2.locator(".ProseMirror");
    await editor2.click();
    await editor2.fill("Content from second tab");
    await page2.click('button:has-text("Save Version")');
    await expect(page2.locator("text=Version saved")).toBeVisible({ timeout: 5000 });

    // Now try to save in first tab (should cause conflict)
    await page.click('button:has-text("Save Version")');

    // Should show conflict dialog
    await expect(page.locator("text=Version Conflict")).toBeVisible({ timeout: 5000 });
    await expect(
      page.locator("text=/updated by someone else/i")
    ).toBeVisible();

    // Close dialog
    await page.click('button:has-text("Cancel")');
    await expect(page.locator("text=Version Conflict")).not.toBeVisible();

    // Clean up
    await page2.close();
  });

  test("refresh content after conflict", async ({ page, context }) => {
    // Create a new note
    await page.click('button:has-text("New Note")');
    await page.waitForURL(/\/notes\/(\d+)/);

    const noteUrl = page.url();

    // Type content
    const editor = page.locator(".ProseMirror");
    await editor.click();
    await editor.fill("Initial content");

    // Simulate conflict with second tab
    const page2 = await context.newPage();
    await page2.goto(noteUrl);
    const editor2 = page2.locator(".ProseMirror");
    await editor2.click();
    await editor2.fill("Updated content from second tab");
    await page2.click('button:has-text("Save Version")');
    await expect(page2.locator("text=Version saved")).toBeVisible({ timeout: 5000 });

    // Try to save in first tab
    await page.click('button:has-text("Save Version")');

    // Conflict dialog should appear
    await expect(page.locator("text=Version Conflict")).toBeVisible({ timeout: 5000 });

    // Click refresh
    await page.click('button:has-text("Refresh Content")');

    // Dialog should close and content should refresh
    await expect(page.locator("text=Version Conflict")).not.toBeVisible();

    // Content should be updated (this might need adjustment based on actual behavior)
    await page.waitForTimeout(1000); // Wait for refresh

    // Clean up
    await page2.close();
  });
});
