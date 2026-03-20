import { test, expect } from '@playwright/test';

const API_URL = process.env.API_URL || 'http://localhost:54321';
const MAILHOG_API = process.env.MAILHOG_API || 'http://localhost:8025/api/v2/messages';

test.describe('Baseline Environment Tests', () => {

  test.describe('Frontend', () => {
    test('should load the app without errors', async ({ page }) => {
      const response = await page.goto('/');
      expect(response?.status()).toBe(200);
    });

    test('should return HTML content', async ({ page }) => {
      await page.goto('/');
      const html = await page.content();
      expect(html).toContain('<html');
    });

    test('should handle SPA deep links', async ({ page }) => {
      const response = await page.goto('/some/deep/link');
      // SPA fallback should still return 200 with the index.html
      expect(response?.status()).toBe(200);
    });
  });

  test.describe('REST API', () => {
    test('should respond to health check', async ({ request }) => {
      const response = await request.get(`${API_URL}/rest/v1/`, {
        headers: {
          'apikey': process.env.ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
        },
      });
      expect(response.ok()).toBeTruthy();
    });
  });

  test.describe('Auth', () => {
    test('should respond to health check', async ({ request }) => {
      const response = await request.get(`${API_URL}/auth/v1/health`);
      expect(response.ok()).toBeTruthy();
    });

    test('should allow email signup', async ({ request }) => {
      const email = `test-${Date.now()}@example.com`;
      const response = await request.post(`${API_URL}/auth/v1/signup`, {
        headers: {
          'apikey': process.env.ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
          'Content-Type': 'application/json',
        },
        data: {
          email,
          password: 'test-password-123!',
        },
      });
      expect(response.ok()).toBeTruthy();
    });

    test('should send confirmation email to MailHog', async ({ request }) => {
      const email = `mailtest-${Date.now()}@example.com`;
      
      // Sign up
      await request.post(`${API_URL}/auth/v1/signup`, {
        headers: {
          'apikey': process.env.ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
          'Content-Type': 'application/json',
        },
        data: {
          email,
          password: 'test-password-123!',
        },
      });

      // Wait a moment for email delivery
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Check MailHog for the email
      const mailResponse = await request.get(MAILHOG_API);
      expect(mailResponse.ok()).toBeTruthy();
      const mailData = await mailResponse.json();
      expect(mailData.total).toBeGreaterThan(0);
    });
  });

  test.describe('Storage', () => {
    const SERVICE_ROLE_KEY = process.env.SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

    test('should respond to status check', async ({ request }) => {
      const response = await request.get(`${API_URL}/storage/v1/status`);
      expect(response.ok()).toBeTruthy();
    });

    test('should upload and download a file', async ({ request }) => {
      const testContent = `smoke-test-${Date.now()}`;
      const fileName = `smoke-${Date.now()}.txt`;

      // Upload
      const uploadResponse = await request.post(
        `${API_URL}/storage/v1/object/llc-smoke/${fileName}`,
        {
          headers: {
            'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
            'Content-Type': 'text/plain',
          },
          data: testContent,
        }
      );
      expect(uploadResponse.ok()).toBeTruthy();

      // Download
      const downloadResponse = await request.get(
        `${API_URL}/storage/v1/object/public/llc-smoke/${fileName}`,
      );
      expect(downloadResponse.ok()).toBeTruthy();
      const body = await downloadResponse.text();
      expect(body).toBe(testContent);
    });
  });

  test.describe('Edge Functions', () => {
    test('should execute smoke function', async ({ request }) => {
      const response = await request.get(`${API_URL}/functions/v1/smoke`);
      expect(response.ok()).toBeTruthy();
      const data = await response.json();
      expect(data.status).toBe('ok');
      expect(data.function).toBe('smoke');
    });
  });

  test.describe('Realtime', () => {
    test('should be reachable', async ({ request }) => {
      // Realtime service should respond (may return various codes but should not timeout)
      try {
        const response = await request.get(`${API_URL}/realtime/v1/`);
        // Any non-timeout response means the service is alive
        expect(response.status()).toBeDefined();
      } catch {
        // If the HTTP request fails, try a basic connectivity check
        const response = await request.get(`${API_URL}/realtime/v1/api/health`);
        expect(response.status()).toBeDefined();
      }
    });
  });

  test.describe('MailHog', () => {
    test('should have accessible UI', async ({ page }) => {
      const mailhogUrl = process.env.MAILHOG_URL || 'http://localhost:8025';
      const response = await page.goto(mailhogUrl);
      expect(response?.status()).toBe(200);
    });
  });
});
