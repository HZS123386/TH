import { build } from 'esbuild';
import { mkdir, readFile, readdir, writeFile, cp } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const target = path.join(root, 'web-client');
await mkdir(path.join(root, 'tmp'), {recursive:true});
const extracted = path.join(root, 'tmp', 'flutter-copy.mjs');
await build({stdin:{contents:`
import {lifeCopy,careerCopy,generationCopy} from './src/lib/lifeReport';
import {ui,readingCopy} from './src/lib/reading';
import {fortuneTopics,fortuneCopy} from './src/lib/fortuneTopics';
export default {life:lifeCopy,career:careerCopy,generation:generationCopy,ui,fortune:fortuneCopy,topics:fortuneTopics,reading:{zh:readingCopy('zh'),th:readingCopy('th')}};`,resolveDir:root},bundle:true,platform:'node',format:'esm',outfile:extracted});
const copy = (await import(pathToFileURL(extracted).href + '?v=' + Date.now())).default;
copy.checkout = JSON.parse(await readFile(path.join(root,'src','content','checkout.json'),'utf8'));
copy.experience = JSON.parse(await readFile(path.join(root,'src','content','experience.json'),'utf8'));
const jy = JSON.parse(await readFile(path.join(root,'src','content','jy.json'),'utf8'));
copy.jy = jy.jy;
copy.jyThemes = jy.jyThemes;
await mkdir(path.join(target,'assets','images'),{recursive:true});
await mkdir(path.join(target,'assets','fonts'),{recursive:true});
await writeFile(path.join(target,'assets','copy.json'),JSON.stringify(copy));
const fontSubset=JSON.parse(await readFile(path.join(target,'assets','fonts','subsets.json'),'utf8'));
const supported=new Set([...fontSubset.ui]);
const dartFiles=(await readdir(path.join(target,'lib'),{recursive:true})).filter(name=>name.endsWith('.dart')&&!name.endsWith('chinese_coverage.dart'));
const uiSource=JSON.stringify(copy)+(await Promise.all(dartFiles.map(name=>readFile(path.join(target,'lib',name),'utf8')))).join('');
const chinese=code=>code>=0x2e80&&code<=0x9fff||code>=0xf900&&code<=0xfaff||code>=0xff00&&code<=0xffef||code>=0x20000&&code<=0x323af;
if([...uiSource].some(char=>chinese(char.codePointAt(0))&&!supported.has(char)))throw Error('Chinese UI font is stale; run scripts/prepare-fonts.py');
for(const name of ['NotoSansThai.ttf','NotoSansSC-Regular.otf','OFL.txt','OFL-CJK.txt']) {
 await cp(path.join(root,'..','TH','app','assets','fonts',name),path.join(target,'assets','fonts',name));
}
await mkdir(path.join(target,'web','media'),{recursive:true});
await cp(path.join(root,'dist','public','fonts'),path.join(target,'web','fonts'),{recursive:true});
await build({entryPoints:[path.join(root,'src','lib','pdfRuntime.ts')],bundle:true,splitting:true,format:'esm',minify:true,outdir:path.join(target,'web','runtime'),entryNames:'report-pdf',chunkNames:'[name]-[hash]'});
// Synthetic fixtures stay inside tests, outside the Flutter asset manifest.
const fixtureModule = path.join(root,'tmp','flutter-fixtures.mjs');
await build({entryPoints:[path.join(root,'tests','fixtures','lifeReport.ts')],bundle:true,platform:'node',format:'esm',outfile:fixtureModule});
const fixtures = await import(pathToFileURL(fixtureModule).href+'?v='+Date.now());
await mkdir(path.join(target,'test','fixtures'),{recursive:true});
for(const lang of ['zh','th']) for(const full of [false,true]) {
 const report = fixtures.reportFixture({...fixtures.inputFor(lang),report_kind:'fortune'},full);
 report.chart = JSON.parse(await readFile(path.join(root,'tests','fixtures','chart.json'),'utf8'));
 await writeFile(path.join(target,'test','fixtures',`${lang}-${full?'full':'preview'}.json`),JSON.stringify(report));
}
console.log('Prepared translations, original document exporters, media and fixtures.');
