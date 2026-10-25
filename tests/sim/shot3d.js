const { chromium } = require('playwright');
(async () => {
  const [,, html, png] = process.argv;
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--allow-file-access-from-files'] });
  const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  p.on('console', m => console.log('console:', m.text()));
  p.on('pageerror', e => console.log('pageerror:', e.message));
  await p.goto('file://' + html);
  await p.waitForFunction('window.done === true', { timeout: 120000 });
  await p.screenshot({ path: png });
  await b.close();
})();
