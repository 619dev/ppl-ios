const { build } = require('esbuild')
const Module = require('node:module')
const path = require('node:path')
const assert = require('node:assert/strict')
const React = require('react')
const { renderToStaticMarkup } = require('react-dom/server')

async function run() {
  const result = await build({
    entryPoints: [path.resolve(__dirname, '../src/components/SessionGate.tsx')],
    bundle: true, platform: 'node', format: 'cjs', write: false, jsx: 'automatic',
    external: ['react', 'react/jsx-runtime'],
    plugins: [{ name: 'observe-redirect', setup(b) {
      b.onResolve({ filter: /^react-router-dom$/ }, () => ({ path: 'router', namespace: 'mock' }))
      b.onLoad({ filter: /.*/, namespace: 'mock' }, () => ({ contents: 'export function Navigate({to}) { globalThis.__redirects.push(to); return null }' }))
    } }],
  })
  const mod = new Module(path.resolve(__dirname, 'session-gate-runtime.cjs'), module)
  mod.filename = path.resolve(__dirname, 'session-gate-runtime.cjs')
  mod.paths = module.paths
  mod._compile(result.outputFiles[0].text, mod.filename)
  const Gate = mod.exports.default
  const render = (authenticated, hydrated) => renderToStaticMarkup(React.createElement(Gate, {
    authenticated, hydrated, loadingLabel: 'Loading',
  }, React.createElement('main', null, 'Chats')))
  global.__redirects = []
  // WebKit rejects 100 history replacements in ten seconds. Slow native
  // restoration must remain on the requested route across repeated renders.
  for (let i = 0; i < 150; i++) assert.match(render(true, false), /role="status"/)
  assert.deepEqual(global.__redirects, [])
  assert.match(render(true, true), /<main>Chats<\/main>/)
  assert.deepEqual(global.__redirects, [])
  assert.match(render(true, false), /Loading/, 'account switches wait for the new account')
  render(false, false)
  assert.deepEqual(global.__redirects, ['/login'], 'signed-out users still reach login')
  console.log('PASS: slow crypto hydration never redirects, ready sessions render, account switches wait, signed-out sessions redirect')
}
run().catch(error => { console.error(error); process.exitCode = 1 })
