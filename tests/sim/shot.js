const { chromium } = require('playwright');
(async () => {
  const [,, html, png, w, h] = process.argv;
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: +w, height: +h } });
  await p.goto('file://' + html);
  await p.waitForTimeout(300);
  await p.screenshot({ path: png });
  await b.close();
})();
