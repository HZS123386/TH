import { defineConfig, devices } from '@playwright/test';
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  workers: 1,
  timeout: 45_000,
  use: {
    baseURL: 'http://127.0.0.1:5174',
    trace: 'retain-on-failure',
    channel:
      process.env.PLAYWRIGHT_CHANNEL || (process.platform === 'win32' ? 'msedge' : undefined),
  },
  projects: [
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 1080 } },
    },
    { name: 'mobile', use: { ...devices['Pixel 7'], defaultBrowserType: 'chromium' } },
  ],
  webServer: {
    command: 'pnpm dev',
    url: 'http://127.0.0.1:5174',
    reuseExistingServer: false,
    timeout: 60_000,
    env: {
      DATABASE_PATH: 'data/e2e.db',
      APP_ENV: 'development',
      DEFAULT_PROVIDER: 'mock',
      SABAI_API_PORT: '8001',
      SABAI_WEB_PORT: '5174',
      SABAI_NO_RELOAD: '1',
      OPENAI_API_KEY: '',
      DEEPSEEK_API_KEY: '',
      QWEN_API_KEY: '',
      KIMI_API_KEY: '',
      EMBEDDING_API_KEY: '',
      ROXY_API_KEY: '',
      ROXY_ENABLED: 'false',
      BAZI_PROVIDER: 'github',
    },
  },
});
