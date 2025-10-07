import { test, expect } from "@playwright/test";

test.describe("Notes", () => {
  test.beforeEach(async ({ page }) => {
    // Login before each test
    await page.goto("/auth/login");
    await page.fill('input[type="email"]', "alice@example.com");
    await page.fill('input[type="password"]', "password123");
    await page.click('button[type="submit"]');
    await page.waitForURL("/");
  });

  test("create a new note", async ({ page }) => {
    // Click "New Note" button
    await page.click('button:has-text("New Note")');

    // Should navigate to note page
    await expect(page).toHaveURL(/\/notes\/\d+/);
    await expect(page.locator('input[placeholder="Note title"]')).toBeVisible();
  });

  test("edit note title", async ({ page }) => {
    // Create new note
    await page.click('button:has-text("New Note")');
    await page.waitForURL(/\/notes\/\d+/);

    // Edit title
    const titleInput = page.locator('input[aria-label="Note title"]');
    await titleInput.fill("My Test Note");
    await titleInput.blur();

    // Should show success toast
    await expect(page.locator("text=Title updated")).toBeVisible({ timeout: 5000 });
  });

  test("save new version with Cmd+S", async ({ page }) => {
    // Create new note
    await page.click('button:has-text("New Note")');
    await page.waitForURL(/\/notes\/\d+/);

    // Type content in editor
    const editor = page.locator(".ProseMirror");
    await editor.click();
    await editor.fill("Test content for version");

    // Save with keyboard shortcut
    await page.keyboard.press("Meta+S");

    // Should show success toast
    await expect(page.locator("text=Version saved")).toBeVisible({ timeout: 5000 });
  });

  test("view version history", async ({ page }) => {
    // Create new note
    await page.click('button:has-text("New Note")');
    await page.waitForURL(/\/notes\/\d+/);

    // Type and save content
    const editor = page.locator(".ProseMirror");
    await editor.click();
    await editor.fill("Version 1 content");
    await page.click('button:has-text("Save Version")');

    // Wait for save
    await expect(page.locator("text=Version saved")).toBeVisible({ timeout: 5000 });

    // Check version history on desktop
    await expect(page.locator("text=Version History")).toBeVisible();

    // On mobile, switch to history tab
    const isMobile = await page.locator('button:has-text("History")').isVisible();
    if (isMobile) {
      await page.click('button:has-text("History")');
    }

    // Should see version in history
    await expect(page.locator("text=/Version #\\d+/")).toBeVisible();
  });

  test("pagination on dashboard", async ({ page }) => {
    // Assuming there are multiple pages of notes
    const nextButton = page.locator('button[aria-label="Next page"]');

    // Check if pagination is visible
    if (await nextButton.isVisible()) {
      await nextButton.click();

      // Should update page indicator
      await expect(page.locator("text=/Page \\d+ of \\d+/")).toBeVisible();
    }
  });
});
