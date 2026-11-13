import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { cp, mkdir, mkdtemp, readFile, readdir, rename, stat, writeFile } from 'node:fs/promises';
import { brotliCompressSync, brotliDecompressSync, constants, gzipSync } from 'node:zlib';
import { homedir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as pause } from 'node:timers/promises';

export const projectRoot=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export const flutterRoot=path.join(projectRoot,'web-client');
const cached=path.join(homedir(),'.cache','fate-sdk','flutter','bin','flutter.bat');
const binary=process.env.FATE_FLUTTER_BIN||(process.platform==='win32'&&existsSync(cached)?cached:'flutter');
// Use the SDK's Dart analyzer so Unicode repository paths keep working.
export function flutter(args){return new Promise((resolve,reject)=>{const tool=args[0]==='analyze'?path.join(path.dirname(binary),process.platform==='win32'?'dart.bat':'dart'):binary;const quote=value=>`'${String(value).replaceAll("'","''")}'`;const command=`& ${quote(tool)} ${args.map(quote).join(' ')}; exit $LASTEXITCODE`;const child=process.platform==='win32'?spawn('powershell.exe',['-NoProfile','-NonInteractive','-Command',command],{cwd:flutterRoot,stdio:'inherit',windowsHide:true}):spawn(tool,args,{cwd:flutterRoot,stdio:'inherit'});child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(Error(`SDK tool exited with ${code}`)));});}
export const basePath=process.env.FATE_H5_BASE_PATH||'/thai-landing/';
if(!/^\/(?:[A-Za-z0-9_-]+\/)*$/.test(basePath))throw Error('FATE_H5_BASE_PATH must be an absolute directory path');
async function moveBuild(source,target){
  for(let attempt=0;;attempt++){
    try{return await rename(source,target);}catch(error){
      if(process.platform!=='win32'||!['EPERM','EBUSY','EACCES'].includes(error.code)||attempt===9)throw error;
      // A preview stream or antivirus scan can briefly hold a Windows file handle.
      await pause(200);
    }
  }
}
export async function buildLanding({release=false}={}){
  await import('./prepare-flutter.mjs');
  const temporary=path.resolve(projectRoot,'tmp'),destination=path.resolve(projectRoot,'site');
  await mkdir(temporary,{recursive:true});
  const generated=await mkdtemp(path.join(temporary,'flutter-site-'));
  const previous=path.join(temporary,`site-previous-${Date.now()}`);
  if(!generated.startsWith(temporary+path.sep)||!previous.startsWith(temporary+path.sep)||destination!==path.join(projectRoot,'site'))throw Error('Unexpected build directory');
  await flutter(['build','web','--release','--wasm','--no-web-resources-cdn',`--base-href=${basePath}`,`--output=${generated}`,'--dart-define=FATE_API_BASE_URL=']);
  const bootstrap=await readFile(path.join(generated,'flutter_bootstrap.js'),'utf8');
  const engineRevision=/"engineRevision":"([a-f0-9]{40})"/.exec(bootstrap)?.[1];
  if(!engineRevision)throw Error('Missing Flutter engine revision');
  // Engine URLs carry their SDK revision, so browsers can safely retain them.
  await mkdir(path.join(generated,'engine'),{recursive:true});
  await rename(path.join(generated,'canvaskit'),path.join(generated,'engine',engineRevision));
  // Ship the existing browser bridge with the bootstrap so it cannot fail as a separate startup request.
  const browserSource=await readFile(path.join(flutterRoot,'web','browser.js'),'utf8');
  const indexPath=path.join(generated,'index.html');
  let index=await readFile(indexPath,'utf8');
  // Discover engine fonts during the HTML request instead of after the Wasm download.
  const fontManifest=JSON.parse(await readFile(path.join(generated,'assets','FontManifest.json'),'utf8'));
  const fontAssets=new Set(fontManifest.flatMap(family=>family.fonts.map(font=>font.asset)));
  fontAssets.delete('assets/fonts/NotoSansThai.ttf'); // Already a high-priority preload.
  const fallbackFont='fonts/fallback/Roboto-Regular.ttf';
  if(existsSync(path.join(generated,'assets',fallbackFont)))fontAssets.add(fallbackFont);
  if(!index.includes('<!-- FATE_FONT_PRELOADS -->'))throw Error('Missing font preload slot');
  index=index.replace('<!-- FATE_FONT_PRELOADS -->',[...fontAssets].map(asset=>`<link rel="preload" href="assets/${asset}" as="fetch" fetchpriority="low" crossorigin>`).join('\n  '));
  if(!index.includes('<script src="browser.js"></script>'))throw Error('Missing browser bootstrap slot');
  await writeFile(indexPath,index.replace('<script src="browser.js"></script>',`<script>${browserSource.replaceAll('</script>','<\\/script>')}</script>`));
  // Preserve the existing report.html deep links, including saved report IDs.
  for (const page of ['report.html','privacy.html','support.html']) {
    await cp(path.join(generated,'index.html'),path.join(generated,page));
  }
  for(const file of ['main.dart.wasm','main.dart.js','browser.js','runtime/report-pdf.js','fonts/pdf/NotoSansThai-Regular.ttf','fonts/pdf/NotoSansSC-Regular.ttf','media/report-loading-web.mp4'])await stat(path.join(generated,file));
  const compressible=new Set(['.html','.js','.mjs','.css','.json','.svg','.wasm','.ttf','.otf']);
  for(const relative of await readdir(generated,{recursive:true})){
    if(!compressible.has(path.extname(relative)))continue;
    const file=path.join(generated,relative),info=await stat(file);
    if(!info.isFile()||info.size<1024)continue;
    const original=await readFile(file);
    await writeFile(file+'.gz',gzipSync(original,{level:9}));
    // Compress during the build so serving Brotli never adds request-time CPU work.
    const brotli=brotliCompressSync(original,{params:{[constants.BROTLI_PARAM_QUALITY]:release?11:6}});
    if(!brotliDecompressSync(brotli).equals(original))throw Error(`Brotli verification failed: ${relative}`);
    if(brotli.length<original.length)await writeFile(file+'.br',brotli);
  }
  if(release)await new Promise((resolve,reject)=>{
    const python=process.env.FATE_PYTHON_BIN||(process.platform==='win32'?'python':'python3');
    const child=spawn(python,[path.join(projectRoot,'scripts','precompress.py'),generated],{cwd:projectRoot,stdio:'inherit',windowsHide:true});
    child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(Error(`Release compression exited with ${code}`)));
  });
  const hadPrevious=existsSync(destination);
  if(hadPrevious)await moveBuild(destination,previous);
  try{await moveBuild(generated,destination);}catch(error){if(hadPrevious)await moveBuild(previous,destination);throw error;}
  console.log(`Flutter H5 build ready: ${destination}`);
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{const args=process.argv.slice(2);if(args.length===1&&args[0]==='release')await buildLanding({release:true});else if(args.length)await flutter(args);else await buildLanding();}catch(error){console.error(error.message);process.exitCode=1;}
}
