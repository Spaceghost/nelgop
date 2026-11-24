'use strict';
// Compare a complete serial frame (or a log with exactly one such frame)
// against an independent full-resolution, exact P6 monitor screenshot.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const [wasmPath, serialPath, ppmPath] = process.argv.slice(2);
assert.ok(wasmPath && serialPath && ppmPath, 'usage: node compare-capture.cjs DECODER.wasm SERIAL HMP.ppm');
function read(file, max) {
  assert.ok(fs.statSync(file).size <= max, 'unexpectedly large fixture');
  return fs.readFileSync(file);
}
const mod = new WebAssembly.Module(read(wasmPath, 65536));
assert.deepEqual(WebAssembly.Module.imports(mod), []);
const api = new WebAssembly.Instance(mod).exports;
const input = read(serialPath, 64*1024*1024);
const magic = Buffer.from('NEBOOT-GOP/1 ');
const off = input.indexOf(magic);
assert.ok(off >= 0 && input.indexOf(magic,off+magic.length) < 0, 'expected exactly one v1 header');
assert.ok(off+24 <= input.length, 'short capture header');
const base = api.__heap_base.value;
const source = base+16;
function ensure(n) {
  if (n > api.memory.buffer.byteLength)
    api.memory.grow(Math.ceil((n-api.memory.buffer.byteLength)/65536));
}
ensure(source+24);
new Uint8Array(api.memory.buffer).set(input.subarray(off,off+24),source);
assert.equal(api.nelgop_wire_header(source,24,base,base+4,base+8),1,'invalid wire header');
const meta = new DataView(api.memory.buffer);
const [width,height,frameSize] = [0,4,8].map(o=>meta.getUint32(base+o,true));
assert.ok(off+frameSize <= input.length, 'short capture body');
const dst = source+frameSize, rgbaSize = width*height*4;
ensure(dst+rgbaSize);
const mem = new Uint8Array(api.memory.buffer);
mem.set(input.subarray(off,off+frameSize),source);
assert.equal(api.nelgop_wire_rgba(source,frameSize,dst,rgbaSize),1,'invalid wire frame');

const ppm = read(ppmPath, 32*1024*1024);
const header = /^P6\n([1-9][0-9]*) ([1-9][0-9]*)\n255\n/.exec(ppm.subarray(0,64).toString('ascii'));
assert.ok(header, 'expected exact QEMU P6 reference');
const sw = Number(header[1]), sh = Number(header[2]), start = header[0].length;
assert.ok(Number.isSafeInteger(sw*sh*3) && sw>=width && sh>=height);
assert.equal(ppm.length-start,sw*sh*3);
const rgb = new Set();
let differences = 0;
for (let y=0; y<height; y++) {
  const sy = Math.floor(((2*y+1)*sh)/(2*height));
  for (let x=0; x<width; x++) {
    const sx = Math.floor(((2*x+1)*sw)/(2*width));
    const a=dst+(y*width+x)*4, b=start+(sy*sw+sx)*3;
    for(let c=0;c<3;c++) if(mem[a+c]!==ppm[b+c]) differences++;
    assert.equal(mem[a+3],255,'invalid RGBA alpha');
    rgb.add((mem[a]<<16)|(mem[a+1]<<8)|mem[a+2]);
  }
}
assert.equal(differences,0,'GOP and independent HMP pixel channels differ');
console.log(`GOP ${width}x${height} vs HMP ${sw}x${sh}: ${differences}/${width*height*3} differing RGB channels, ${rgb.size} colors`);
