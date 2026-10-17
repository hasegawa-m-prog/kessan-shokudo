// 開発用の画面確認。実行には Node.js と Playwright が必要です。
// 新規テストユーザーを1件作成します。通常はローカルのみ。
// 承認済み本番の初回確認時だけ --production-smoke を明示します。
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const { randomBytes } = require('node:crypto');
const production = process.argv.includes('--production-smoke');
const baseUrl = production ? 'https://kessan-shokudo.onrender.com' : 'http://127.0.0.1:3000';
const screenshotPrefix = production ? 'production' : 'home';

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => { if (response.status() >= 500) errors.push(`${response.status()} ${response.url()}`); });
  try {
    const initialResponse = await page.goto(baseUrl);
    assert.equal(initialResponse.status(), 200);
    if (production) assert(initialResponse.headers()['strict-transport-security']);
    await page.getByRole('heading', { name: /会社の数字を、.*わかる楽しさに。/ }).waitFor();
    await page.screenshot({ path: path.join(__dirname, `../tmp/${screenshotPrefix}-desktop.png`), fullPage: true });
    for (const width of [ 375, 390, 768 ]) {
      await page.setViewportSize({ width, height: 844 });
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `TOP overflow: ${width}`);
    }
    await page.screenshot({ path: path.join(__dirname, `../tmp/${screenshotPrefix}-tablet.png`), fullPage: true });
    await page.setViewportSize({ width: 390, height: 844 });
    await page.screenshot({ path: path.join(__dirname, `../tmp/${screenshotPrefix}-mobile.png`), fullPage: true });
    await page.getByRole('navigation').getByRole('link', { name: 'ユーザー登録' }).click();
    const email = `browser-check-${Date.now()}@example.com`;
    const password = randomBytes(24).toString('hex');
    await page.getByLabel('メールアドレス').fill(email);
    await page.getByLabel('パスワード（12文字以上）', { exact: true }).fill(password);
    await page.getByLabel('確認用パスワード', { exact: true }).fill('wrong-confirmation');
    await page.getByRole('button', { name: '登録する', exact: true }).click();
    await page.getByRole('alert').waitFor();
    await page.getByLabel('パスワード（12文字以上）', { exact: true }).fill(password);
    await page.getByLabel('確認用パスワード', { exact: true }).fill(password);
    await page.getByRole('button', { name: '登録する', exact: true }).click();
    await page.waitForURL('**/login');
    assert(await page.getByRole('status').innerText().then(text => text.includes('登録が完了しました')));
    await page.getByLabel('メールアドレス').fill(email);
    await page.getByLabel('パスワード', { exact: true }).fill('incorrect-password');
    await page.getByRole('button', { name: 'ログインする' }).click();
    await page.getByRole('alert').waitFor();
    await page.getByLabel('パスワード', { exact: true }).fill(password);
    await page.getByRole('button', { name: 'ログインする' }).click();
    await page.waitForURL(`${baseUrl}/`);
    await page.reload();
    await page.getByText('ログイン中', { exact: true }).waitFor();
    if (production) {
      const cookie = (await page.context().cookies()).find(cookie => cookie.name === '_kessan_shokudo_session');
      assert(cookie && cookie.secure && cookie.httpOnly && cookie.sameSite === 'Lax');
    }
    await page.getByRole('button', { name: 'ログアウト', exact: true }).click();
    await page.getByRole('navigation').getByRole('link', { name: 'ログイン', exact: true }).waitFor();
    assert.equal(await page.getByText('ログイン中', { exact: true }).count(), 0);
    await page.getByRole('navigation').getByRole('link', { name: 'ログイン', exact: true }).click();
    await page.getByLabel('メールアドレス').fill(email);
    await page.getByLabel('パスワード', { exact: true }).fill(password);
    await page.getByRole('button', { name: 'ログインする' }).click();
    await page.getByText('ログイン中', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'ログアウト', exact: true }).click();
    assert.deepEqual(errors, []);
    console.log(JSON.stringify({ result: 'passed', target: baseUrl, checks: ['desktop/mobile layout', 'registration errors', 'registration', 'login errors', 'login persistence', 'logout and re-login', 'no browser or server errors', ...(production ? ['HTTPS/HSTS', 'Secure/HttpOnly/SameSite cookies'] : [])], testEmail: email }));
  } finally {
    await browser.close();
  }
})();
