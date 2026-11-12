// Exercise the exact browser script embedded in Main.gd with browser API doubles.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('Scripts/Main.gd', 'utf8').match(/const GPX_PICKER_SCRIPT := """([\s\S]*?)"""/)[1];
const file = (name, size = 100) => ({name, size, text: async () => '<gpx/>'});
const handle = name => ({name, getFile: async () => file(name)});

async function run() {
  let calls = [];
  let options = [];
  const first = handle('First.gpx');
  const second = handle('Second.gpx');
  const window = {isSecureContext: true, bathysGpxImport: (...args) => calls.push(args),
    showOpenFilePicker: async opts => { options.push(opts); return [first, second]; }};
  let context = vm.createContext({window});
  await vm.runInContext(source, context);
  assert.equal(options[0].multiple, true);
  assert.equal(options[0].id, 'bathys-gpx');
  assert.equal(calls.map(x => x[2]).join(','), 'begin,,,end');
  assert.equal(calls[1][1], 'First.gpx');
  assert.equal(calls[2][1], 'Second.gpx');
  calls = [];
  await vm.runInContext(source, context);
  assert.equal(options[1].startIn, first);
  assert.equal(options[1].id, options[0].id);
  calls = [];
  window.showOpenFilePicker = async () => { throw Object.assign(new Error(), {name: 'AbortError'}); };
  await vm.runInContext(source, context);
  assert.equal(calls.length, 0);

  let input;
  let created = 0;
  const document = {getElementById: () => input,
    createElement: () => { created++; return {style: {}, click() { this.clicked = true; }}; },
    body: {appendChild: element => { input = element; }}};
  calls = [];
  const fallback = {isSecureContext: false, bathysGpxImport: (...args) => calls.push(args)};
  context = vm.createContext({window: fallback, document});
  await vm.runInContext(source, context);
  assert.equal(input.multiple, true);
  assert.equal(input.clicked, true);
  input.files = [file('Good.gpx'), file('Too big.gpx', 10485761),
    {name: 'Unreadable.gpx', text: async () => { throw Error('read failure'); }}, file('Last.gpx')];
  await input.onchange();
  assert.equal(calls.map(x => x[2]).join(','), 'begin,,large,read,,end');
  assert.equal(calls[4][1], 'Last.gpx');
  input.value = 'previous selection';
  await vm.runInContext(source, context);
  assert.equal(created, 1);
  assert.equal(input.value, '');
  assert.equal(input.multiple, true);
  // A browser that exposes the modern API but disallows it still gets the fallback.
  fallback.isSecureContext = true;
  fallback.showOpenFilePicker = async () => { throw Object.assign(new Error(), {name: 'SecurityError'}); };
  await vm.runInContext(source, context);
  assert.equal(input.clicked, true);
  console.log('GPX browser picker: multiple selection, remembered handle, cancellation, fallback reuse and per-file failures passed');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
