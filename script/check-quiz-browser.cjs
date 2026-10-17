// ローカル専用。quiz:seed_demoの登録後に実行します。架空の会員を1件作ります。
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const path = require('node:path');
const baseUrl = 'http://127.0.0.1:3000';

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => { if (response.status() >= 500) errors.push(`${response.status()} ${response.url()}`); });
  const checkWidth = async () => assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `横はみ出し: ${page.url()}`);
  try {
    for (const industry of [ '小売業', '製造業', 'サービス業', 'おまかせ（全業種から出題）' ]) {
      await page.goto(`${baseUrl}/quiz/new`);
      for (const width of [ 375, 390, 768, 1280 ]) {
        await page.setViewportSize({ width, height: 844 });
        await checkWidth();
      }
      await page.setViewportSize({ width: 390, height: 844 });
      await page.getByLabel(industry, { exact: true }).check();
      await page.getByRole('button', { name: '5問のクイズを始める' }).click();
      const questionChoices = new Set();
      for (let index = 1; index <= 5; index++) {
        const firstChoiceId = await page.locator('input[name="choice_id"]').first().inputValue();
        assert(!questionChoices.has(firstChoiceId));
        questionChoices.add(firstChoiceId);
        assert.equal(await page.locator('input[name="choice_id"]').count(), 3);
        const beforeCount = await page.locator('.balance-sheet').count();
        assert([ 1, 2 ].includes(beforeCount));
        assert.equal(await page.locator('.explanation').count(), 0);
        await checkWidth();
        if (industry === '小売業' && index === 1) {
          await page.screenshot({ path: path.join(__dirname, '../tmp/quiz-question-mobile.png'), fullPage: false });
        }
        await page.locator('input[name="choice_id"]').first().check();
        await page.getByRole('button', { name: '回答する', exact: true }).click();
        await page.getByRole('region', { name: '回答結果' }).waitFor();
        assert.equal(await page.locator('.balance-sheet').count(), 2);
        await checkWidth();
        if (industry === '小売業' && index === 1) {
          await page.locator('.diagrams').scrollIntoViewIfNeeded();
          await page.screenshot({ path: path.join(__dirname, '../tmp/quiz-diagrams-mobile.png'), fullPage: false });
          await page.setViewportSize({ width: 1280, height: 900 });
          await checkWidth();
          await page.locator('.diagrams').scrollIntoViewIfNeeded();
          await page.screenshot({ path: path.join(__dirname, '../tmp/quiz-diagrams-desktop.png'), fullPage: false });
          await page.setViewportSize({ width: 390, height: 844 });
        }
        if (beforeCount === 1) await page.getByRole('heading', { name: '増減を文字で確認' }).waitFor();
        await page.getByRole('link', { name: index === 5 ? '5問の結果を見る' : '次の問題へ', exact: true }).click();
      }
      await page.getByRole('heading', { name: '5問、おつかれさまでした。' }).waitFor();
      assert.equal(await page.locator('.result-list li').count(), 5);
      await checkWidth();
      await page.screenshot({ path: path.join(__dirname, '../tmp/quiz-result-mobile.png'), fullPage: false });
    }
    // 同じブラウザでも、登録・ログイン前のゲスト記録は引き継がれません。
    await page.goto(`${baseUrl}/signup`);
    const email = `quiz-browser-${Date.now()}@example.com`;
    const password = randomBytes(24).toString('hex');
    await page.getByLabel('メールアドレス').fill(email);
    await page.getByLabel('パスワード（12文字以上）', { exact: true }).fill(password);
    await page.getByLabel('確認用パスワード', { exact: true }).fill(password);
    await page.getByRole('button', { name: '登録する', exact: true }).click();
    await page.getByLabel('メールアドレス').fill(email);
    await page.getByLabel('パスワード', { exact: true }).fill(password);
    await page.getByRole('button', { name: 'ログインする' }).click();
    await page.goto(`${baseUrl}/quiz`);
    await page.waitForURL('**/quiz/new');
    await page.getByLabel('小売業', { exact: true }).check();
    await page.getByRole('button', { name: '5問のクイズを始める' }).click();
    for (let index = 1; index <= 5; index++) {
      await page.locator('input[name="choice_id"]').last().check();
      await page.getByRole('button', { name: '回答する', exact: true }).click();
      await page.getByRole('link', { name: index === 5 ? '5問の結果を見る' : '次の問題へ', exact: true }).click();
    }
    await page.getByText('ログイン中の回答は保存されます。', { exact: false }).waitFor();
    await page.getByRole('button', { name: 'ログアウト', exact: true }).click();
    await page.getByRole('navigation').getByRole('link', { name: 'ログイン', exact: true }).click();
    await page.getByLabel('メールアドレス').fill(email);
    await page.getByLabel('パスワード', { exact: true }).fill(password);
    await page.getByRole('button', { name: 'ログインする' }).click();
    await page.getByRole('navigation').getByRole('link', { name: '回答履歴', exact: true }).click();
    assert.equal(await page.locator('.history-list li').count(), 5);
    await checkWidth();
    await page.locator('.history-list h2 a').first().click();
    await page.getByRole('region', { name: '回答結果' }).waitFor();
    await page.getByRole('navigation').getByRole('link', { name: '復習', exact: true }).click();
    assert.equal(await page.locator('.history-list li').count(), 4);
    await page.getByRole('button', { name: 'この問題を復習する', exact: true }).first().click();
    await page.locator('input[name="choice_id"]').first().check();
    await page.getByRole('button', { name: '回答する', exact: true }).click();
    await page.getByRole('status').waitFor();
    await checkWidth();
    await page.getByRole('navigation').getByRole('link', { name: '回答履歴', exact: true }).click();
    assert.equal(await page.locator('.history-list li').count(), 6);
    await page.screenshot({ path: path.join(__dirname, '../tmp/quiz-history-mobile.png'), fullPage: false });
    await page.getByRole('button', { name: 'ログアウト', exact: true }).click();
    assert.deepEqual(errors, []);
    console.log(JSON.stringify({ result: 'passed', guestRuns: 4, memberRuns: 1, reviewRuns: 1, testEmail: email, checks: ['26 questions answered', 'no answer leakage', 'two diagrams after answer', 'transaction changes', 'mobile and desktop widths', 'guest data not transferred', 'history after re-login', 'separate review answer saved', 'no browser or server errors'] }));
  } finally {
    await browser.close();
  }
})();
