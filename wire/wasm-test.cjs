'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const m = new WebAssembly.Module(fs.readFileSync(process.argv[2]));
assert.deepEqual(WebAssembly.Module.imports(m), []);
assert.deepEqual(WebAssembly.Module.exports(m).map(x=>x.name).sort(),
  ['__heap_base','memory','nelgop_wire_header','nelgop_wire_rgba']);
const x = new WebAssembly.Instance(m).exports;
const base = x.__heap_base.value;
const src = base + 16;
const rgb = Buffer.alloc(160 * 100 * 3);
for(let i=0;i<rgb.length;i++) rgb[i]=(13*i+77)&255;
const lines = ['NEBOOT-GOP/1 00a0 0064\r\n'];
for(let y=0;y<100;y++) lines.push(rgb.subarray(480*y,480*(y+1)).toString('hex')+'\r\n');
lines.push('NEBOOT-GOP/END\r\n');
const wire = Buffer.from(lines.join(''));
assert.equal(wire.length,96240);
const dst = src + wire.length;
const rgba = 160 * 100 * 4;
const pages = Math.ceil((dst+rgba+4-x.memory.buffer.byteLength)/65536);
if(pages>0)x.memory.grow(pages);
const mem=new Uint8Array(x.memory.buffer), meta=new DataView(x.memory.buffer);
mem.set(wire,src);
assert.equal(x.nelgop_wire_header(src,24,base,base+4,base+8),1);
assert.equal(meta.getUint32(base,true),160);
assert.equal(meta.getUint32(base+4,true),100);
assert.equal(meta.getUint32(base+8,true),wire.length);
mem.fill(77,dst,dst+rgba+4);
assert.equal(x.nelgop_wire_rgba(src,wire.length,dst,rgba-1),0);
mem[src+wire.length-19]=90; // Last row's final hex digit; trailer remains valid.
assert.equal(x.nelgop_wire_rgba(src,wire.length,dst,rgba),0);
assert.ok(mem.subarray(dst,dst+rgba+4).every(v=>v===77));
mem.set(wire,src);
assert.equal(x.nelgop_wire_rgba(src,wire.length,dst,rgba+4),1);
for(let p=0;p<16000;p++) {
  assert.equal(mem[dst+p*4],rgb[p*3]);
  assert.equal(mem[dst+p*4+1],rgb[p*3+1]);
  assert.equal(mem[dst+p*4+2],rgb[p*3+2]);
  assert.equal(mem[dst+p*4+3],255);
}
assert.ok(mem.subarray(dst+rgba,dst+rgba+4).every(v=>v===77));
console.log('Wasm zero imports, exact 160x100 wire, failure atomicity, and all 64000 RGBA bytes: PASS');
