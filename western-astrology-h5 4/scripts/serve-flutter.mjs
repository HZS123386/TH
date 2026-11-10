import { createServer, request as httpRequest } from 'node:http';
import { request as httpsRequest } from 'node:https';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import { projectRoot,basePath,buildLanding } from './build-flutter.mjs';
const port=Number(process.env.FATE_H5_PORT||8765),upstream=new URL(process.env.FATE_API_UPSTREAM||'http://127.0.0.1:8000');
if(!Number.isInteger(port)||port<1||port>65535||!['http:','https:'].includes(upstream.protocol))throw Error('Invalid local server settings');
if(!process.argv.includes('--skip-build'))await buildLanding();
const root=path.resolve(projectRoot,'site');
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript','.mjs':'text/javascript','.css':'text/css','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.svg':'image/svg+xml','.webp':'image/webp','.ttf':'font/ttf','.otf':'font/otf','.woff2':'font/woff2','.mp4':'video/mp4'};
const server=createServer(async(req,res)=>{
 let url;try{url=new URL(req.url,'http://localhost');}catch{res.writeHead(400).end();return;}
 if(url.pathname.startsWith('/api/')||url.pathname==='/health'){
  const target=new URL(url.pathname+url.search,upstream),send=target.protocol==='https:'?httpsRequest:httpRequest;
  const proxy=send(target,{method:req.method,headers:{...req.headers,host:target.host}},response=>{res.writeHead(response.statusCode||502,response.headers);response.pipe(res);});
  proxy.on('error',()=>{if(res.headersSent){res.destroy();return;}res.writeHead(503,{'Content-Type':'application/json'}).end(JSON.stringify({detail:'Service unavailable'}));});req.on('aborted',()=>proxy.destroy());req.pipe(proxy);return;
 }
 if(!['GET','HEAD'].includes(req.method)){res.writeHead(405).end();return;}
 if(basePath!=='/'&&url.pathname===basePath.slice(0,-1)){res.writeHead(302,{Location:basePath+url.search}).end();return;}
 if(basePath!=='/'&&(url.pathname==='/'||url.pathname==='/report.html')){res.writeHead(302,{Location:basePath+(url.pathname==='/report.html'?'report.html':'')+url.search}).end();return;}
 if(!url.pathname.startsWith(basePath)){res.writeHead(404).end();return;}
 let file;try{file=path.resolve(root,decodeURIComponent(url.pathname.slice(basePath.length))||'index.html');}catch{res.writeHead(400).end();return;}
 if(file!==root&&!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
 try{
  if((await stat(file)).isDirectory())file=path.join(file,'index.html');
  const info=await stat(file),etag=`W/"${info.size.toString(16)}-${info.mtimeMs.toString(16)}"`;
  const headers={'Content-Type':mime[path.extname(file)]||'application/octet-stream','Cache-Control':'no-cache',ETag:etag};
  if(req.headers['if-none-match']===etag){res.writeHead(304,headers).end();return;}
  const range=req.headers.range;
  if(range&&path.extname(file)==='.mp4'){
   const match=/^bytes=(\d*)-(\d*)$/.exec(range);let start,end;
   if(match){start=match[1]?Number(match[1]):Math.max(0,info.size-Number(match[2]));end=match[1]?(match[2]?Math.min(Number(match[2]),info.size-1):info.size-1):info.size-1;}
   if(!match||!Number.isSafeInteger(start)||!Number.isSafeInteger(end)||start<0||start>=info.size||end<start){res.writeHead(416,{'Content-Range':`bytes */${info.size}`}).end();return;}
   res.writeHead(206,{...headers,'Accept-Ranges':'bytes','Content-Range':`bytes ${start}-${end}/${info.size}`,'Content-Length':end-start+1});if(req.method==='HEAD')res.end();else createReadStream(file,{start,end}).pipe(res);return;
  }
  res.writeHead(200,{...headers,'Content-Length':info.size,...(path.extname(file)==='.mp4'?{'Accept-Ranges':'bytes'}:{})});if(req.method==='HEAD')res.end();else createReadStream(file).pipe(res);
 }catch{if(!res.headersSent)res.writeHead(404).end();else res.destroy();}
});
server.listen(port,'127.0.0.1',()=>console.log(`FATE Flutter H5: http://127.0.0.1:${port}${basePath}`));
process.on('SIGINT',()=>server.close());process.on('SIGTERM',()=>server.close());
