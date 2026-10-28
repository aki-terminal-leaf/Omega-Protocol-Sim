// SPDX-License-Identifier: MIT
import {build} from 'esbuild';
import {cp,readFile,writeFile,readdir,stat} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve,dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const here=dirname(fileURLToPath(import.meta.url));
const args=process.argv.slice(2),value=k=>{const i=args.indexOf(k);return i<0?null:args[i+1];};
if(!value('--data')||!value('--out'))throw Error('Usage: npm run build -- --data PRIVATE_OFFLINE_DATA --out NEW_OUTPUT_DIRECTORY');
const data=resolve(value('--data')),out=resolve(value('--out'));
try{await stat(out);throw Error('Output must be a fresh directory, not an accepted build');}catch(e){if(e.code!=='ENOENT')throw e;}
for(const name of ['manifest.js','record.js','weapon-data.js','full-data.js','assets'])await stat(join(data,name));
await cp(data,out,{recursive:true,force:false,errorOnExist:true});
await cp(join(here,'src/index.html'),join(out,'index.html'));
await build({entryPoints:[join(here,'src/viewer.js')],bundle:true,format:'iife',outfile:join(out,'viewer.js')});
let prior={};try{prior=JSON.parse(await readFile(join(out,'VALIDATION.json'),'utf8'));}catch{}
await writeFile(join(out,'VALIDATION.json'),JSON.stringify({version:'0.1.0',runtime_validation:'NOT_RUN_FOR_THIS_NEW_BUILD',rendering_complete:false,upstream_reference_validation:prior},null,2));
const hashes={};async function walk(dir,base=''){for(const name of await readdir(dir)){const rel=base?base+'/'+name:name,path=join(dir,name),s=await stat(path);if(s.isDirectory())await walk(path,rel);else if(rel!=='SHA256.json')hashes[rel]=createHash('sha256').update(await readFile(path)).digest('hex');}}
await walk(out);await writeFile(join(out,'SHA256.json'),JSON.stringify(hashes,null,2));
console.log(JSON.stringify({output:out,files:Object.keys(hashes).length,runtime_validation:'NOT_RUN_FOR_THIS_NEW_BUILD'}));
