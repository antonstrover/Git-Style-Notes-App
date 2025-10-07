import { test, expect } from "@playwright/test";

test.describe("Authentication", () => {
  test("should show login page for unauthenticated users", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveURL(/\/auth\/login/);
  });

  test("login flow with valid credentials", async ({ page }) => {
    await page.goto("/auth/login");

    // Fill in credentials
    await page.fill('input[type="email"]', "alice@example.com");
    await page.fill('input[type="password"]', "password123");

    // Submit form
    await page.click('button[type="submit"]');

    // Should redirect to dashboard
    await expect(page).toHaveURL("/");
    await expect(page.locator("text=My Notes")).toBeVisible();
  });

  test("login flow with invalid credentials", async ({ page }) => {
    await page.goto("/auth/login");

    // Fill in invalid credentials
    await page.fill('input[type="email"]', "invalid@example.com");
    await page.fill('input[type="password"]', "wrongpassword");

    // Submit form
    await page.click('button[type="submit"]');

    // Should show error message
    await expect(page.locator("text=/Invalid|Error|Failed/i")).toBeVisible();
  });

  test("logout flow", async ({ page, context }) => {
    // Login first
    await page.goto("/auth/login");
    await page.fill('input[type="email"]', "alice@example.com");
    await page.fill('input[type="password"]', "password123");
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL("/");

    // Click logout
    await page.click('button[aria-label="Logout"]');

    // Should redirect to login
    await expect(page).toHaveURL(/\/auth\/login/);
  });
});
