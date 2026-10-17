// ローカル専用。quiz:seed_public後は --public を付ける。架空の会員を1件作ります。
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const baseUrl = 'http://127.0.0.1:3000';
const publicData = process.argv.includes('--public') ? JSON.parse(readFileSync(path.join(__dirname, '../db/data/questions_v1.json'), 'utf8')) : null;

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => { if (response.status() >= 500) errors.push(`${response.status()} ${response.url()}`); });
  const checkWidth = async () => assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `横はみ出し: ${page.url()}`);
  const verifiedCodes = new Set();
  const verifyPublicDiagrams = async () => {
    if (!publicData) return;
    const title = await page.locator('.learning h1').innerText();
    const question = publicData.questions.find(question => question.title === title);
    assert(question, `公開原稿にない問題: ${title}`);
    const cards = page.locator('.balance-sheet');
    const maximum = Math.max(...question.sheets.map(sheet => sheet.amounts.slice(0, 3).reduce((a, b) => a + b, 0)));
    for (let index = 0; index < 2; index++) {
      const sheet = question.sheets[index];
      const card = cards.nth(index);
      assert((await card.locator('h3').innerText()).includes(sheet.company_name));
      const rects = await card.locator('rect').evaluateAll(nodes => nodes.map(node => ({
        title: node.querySelector('title').textContent, category: node.getAttribute('class'),
        x: Number(node.getAttribute('x')), height: Number(node.getAttribute('height'))
      })));
      assert.equal(rects.length, 5);
      const total = sheet.amounts.slice(0, 3).reduce((a, b) => a + b, 0);
      for (let accountIndex = 0; accountIndex < 5; accountIndex++) {
        const account = publicData.accounts[accountIndex];
        const amount = sheet.amounts[accountIndex];
        const formatted = `${amount.toLocaleString('en-US')}円`;
        const rect = rects.find(rect => rect.title === `${account.name}：${formatted}`);
        assert(rect, `${question.code}: ${account.name}の金額不一致`);
        assert(rect.category.includes(account.category));
        assert.equal(rect.x, account.category === 'asset' ? 10 : 170);
        assert(Math.abs(rect.height - amount / maximum * 180) < 0.00001);
        const row = card.locator('.amount-list > div').filter({ has: page.locator('dt', { hasText: account.name }) });
        const text = await row.innerText();
        assert(text.includes(formatted));
        assert(text.includes(`${(amount / total * 100).toFixed(1)}%`));
      }
      assert.deepEqual(await card.locator('svg > text[y="234"]').allTextContents(), Array(2).fill(`合計 ${total.toLocaleString('en-US')}円`));
    }
    for (const width of [375, 390, 768, 1280]) {
      await page.setViewportSize({ width, height: 900 });
      await checkWidth();
      if (width > 640) {
        const boxes = await cards.locator('svg').evaluateAll(nodes => nodes.map(node => {
          const box = node.getBoundingClientRect();
          return { y: box.y, width: box.width, height: box.height };
        }));
        for (const dimension of ['y', 'width', 'height']) {
          assert(Math.abs(boxes[0][dimension] - boxes[1][dimension]) < 1, `${question.code}: BSの表示位置・縮尺が不一致`);
        }
      }
    }
    if (['bs-r1', 'bs-m4', 'bs-s5'].includes(question.code)) {
      await page.locator('.diagrams').scrollIntoViewIfNeeded();
      await page.screenshot({ path: path.join(__dirname, `../tmp/public-${question.code}-desktop.png`) });
    }
    await page.setViewportSize({ width: 390, height: 844 });
    verifiedCodes.add(question.code);
  };
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
        await verifyPublicDiagrams();
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
    if (publicData) assert.equal(verifiedCodes.size, 15);
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
    console.log(JSON.stringify({ result: 'passed', publicQuestionsVerified: verifiedCodes.size, guestRuns: 4, memberRuns: 1, reviewRuns: 1, testEmail: email, checks: ['26 questions answered', 'no answer leakage', 'two diagrams after answer', 'transaction changes', 'mobile and desktop widths', 'guest data not transferred', 'history after re-login', 'separate review answer saved', 'no browser or server errors'] }));
  } finally {
    await browser.close();
  }
})();
