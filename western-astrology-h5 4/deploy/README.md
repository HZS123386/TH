# 腾讯云落地页部署

部署目标为 `ubuntu@129.226.126.212`。使用当前本地落地页及相邻的 `TH` 后端源码，保留服务器已有的 `ipplay.top` 网站。

- 域名入口：`https://fatehoro.top/`，进入 `/thai-landing/` 后默认泰语；中文入口为 `https://fatehoro.top/thai-landing/?lang=zh`。
- `www.fatehoro.top` 自动跳转至主域名；旧域名入口 `https://ipplay.top/thai-landing/` 继续保留。
- 原 IP 入口：`https://129.226.126.212/thai-landing/?lang=zh`。
- 健康检查：`http://129.226.126.212/health`
- 应用容器：`astro-life-report`，Python 3.12、Node.js 24、单个 Uvicorn worker。
- 当前发布目录：`/opt/astro-life-report/current`，指向 `releases/` 中的版本。
- 持久化数据：`/opt/astro-life-report/shared/data`，包括地点索引和新生成的报告数据库。
- 服务端配置：`/opt/astro-life-report/shared/runtime.env`，仅服务器 root 可读。
- 入口配置：`/opt/astro-life-report/shared/Caddyfile`，沿用现有 Caddy 网关，另外增加公网 IP 站点。
- 网关修改前的备份：`/opt/astro-life-report/shared/backups/ingress-*`。

配置 Sunlands 后使用手机号建单、官方收银台和服务端查单核验，核对订单、币种和到账金额后才解锁报告。production 仅允许 Sunlands 正式网关；测试网关和 Payso Demo 仍限 development。TH 的本地开发登录入口在 production 环境关闭，公网入口只转发落地页、地点查询、人生报告接口和健康检查。

## 日常查看

通过 SSH 登录服务器后执行：

```sh
cd /opt/astro-life-report/current
sudo docker compose ps
sudo docker compose logs --tail 80 app
```

应用设置了自动重启策略。服务器的 Docker 服务已启用开机启动。请保留 `shared/data`，不要用开发机的个人报告数据库覆盖它。

## 制作新版本

在统一仓库总目录执行 `pnpm deploy:prepare`，或在落地页目录执行同名命令。已有最新构建时，可在落地页目录执行 `node ../TH/scripts/python.mjs -X utf8 deploy/prepare_release.py` 仅打包。生成结果固定为总目录的 `output/deploy/latest/`，上一份保留在 `output/deploy/previous/`；不在桌面创建项目副本。发布版本号仍写入 manifest，服务器端的版本和回滚流程保持原样。普通本地构建可使用 `pnpm build`。

发布包包含后端、排盘脚本及库、`TH/src/content`、`TH/src/locales`、`TH/src/data` 中的运行资源，以及落地页 `site` 构建目录。报告校验代码会读取这些语言资源，不能只复制 Python 文件。

`runtime.env` 与应用压缩包分开生成和上传，不进入 Docker 构建上下文。打包程序会检查构建文件中是否包含本机已配置的密钥，并排除原有用户数据库。地点索引单独复制，后续版本复用服务器已有文件。

更新现有服务器时，保留线上已有的模型、数据库路径和环境模式，只合并本次明确要发布的配置项；不要用包含本机代理地址的开发配置整体覆盖线上 `runtime.env`。支付凭据同样只放在该私有配置文件中，发布前备份旧配置，失败时连同应用版本一起恢复。部署验收不创建真实订单或付款。

首次部署依次使用 `stage_server.sh`、`start_server.sh` 和 `publish_proxy.py`。后续更新只需构建和启动新应用版本。需要修改已有 IP 入口时，向网关脚本额外提供上个版本的 `Caddyfile.ip` 路径；只有旧配置逐字匹配时才替换该站点，避免重复添加或改动其他网站。

复用 `ipplay.top` 时，`Caddyfile.domain` 仅包含落地页静态资源及报告接口路由，插入原站域名配置，不接管 `/`、`/api/v1/` 或管理后台。通过 `publish_proxy.py <本次IP配置> <现有IP配置> --domain-routes Caddyfile.domain --release vYYYY.MM.DD.N` 校验后热重载，所有容器保持运行。配置更新也使用独立版本，回执写入 `/opt/ipplay/shared/releases/`，原网关备份放在 `/opt/ipplay/shared/config-releases/<版本>/`，同步更新原站 `deploy/server/releases.json`。后续更换独立域名时只调整网关和 DNS，应用继续使用同源接口及 `/thai-landing/` base 路径。

独立域名使用 `Caddyfile.fatehoro`，复用现有 `astro_landing_routes`，不改变原 `APP_DOMAIN=ipplay.top`。DNSPod 将 `@` 和 `www` 指向 `129.226.126.212`；Caddy 沿用证书持久化卷自动签发和续期免费 HTTPS。解析生效后，通过 `publish_proxy.py <本次IP配置> <现有IP配置> --site-routes Caddyfile.fatehoro --release vYYYY.MM.DD.N` 校验、备份并热重载。根路径跳转保留语言等查询参数，`www` 统一跳到裸域；落地页和报告接口保持同源。此次不更换应用镜像、模型配置或数据库。

新旧域名和原 IP 属于不同浏览器来源，已有报告访问凭证不会自动转到新域名。保留旧域名及原 IP 入口供已有访客查看历史报告，不把访问凭证放进 URL，也不强制将历史报告链接跳到新域名。

## 首屏资源

本地构建现已切换为 Flutter Web。发布时继续复制 `site/`，不需要在服务器安装 Flutter；后端挂载 `/thai-landing/` 的方式和报告数据库位置保持一致。构建必须使用相同的 base 路径。`.mjs` 应返回 JavaScript MIME，`.wasm` 应返回 `application/wasm`，字体和视频须能从同源访问。下述旧版响应式图片方案仅适用于历史 React 构建；新版使用本地 Flutter 渲染引擎与字体，实际校验记录见 `../docs/FLUTTER_H5_MIGRATION.md`。

Flutter 版首屏预加载欢迎页主图、所需字体和资源清单，翻译与中文字库并行准备。表单和主题图板在用户开始进入首页时构建，不参与欢迎页首帧；主题图片在欢迎页可见后预取，进入表单时复用同一人物图片的缓存。人物图片不再挂起整页首帧；欢迎页在收到真实绘制通知前继续请求帧，避免引擎批量上报帧计时造成加载层停留。图片请求或解码失败后先清除失败缓存，再有限重试，最终提供手动重试入口并保持版面尺寸。

构建时把现有 browser.js 与启动代码一起写入 HTML，减少启动所需的独立请求。文案和中文字库加载失败时最多尝试三次；启动失败最多自动重新加载一次，成功后清除本次恢复标记，持续失败则显示手动重载入口。JavaScript 入口请求失败和 Dart 初始化失败都接入同一加载状态，慢网不会单独触发自动刷新。HTML 加载提示在真实首帧完成后移除。

中文界面使用约 358 KB 精简 OTF。HTML 启动阶段预加载中文界面以及缅甸语、高棉语、老挝语的小字库：当前语言为高优先级，其余为低优先级，并在首帧绘制后注册，首次切换复用同一请求。进入表单或切换中文不再主动下载约 2 MB 的常用中文字库；只有城市名、报告等实际文本超出界面字库时才按需加载常用或完整字库。符号字体约 24 KB，原字体格式和渲染方式保持一致。Python 静态服务显式注册 font/otf、font/ttf、font/woff2 与 image/webp MIME，避免精简 Linux 镜像返回错误类型。PDF 字体独立保留。

Flutter 的入口、业务文件和资源清单继续使用 no-cache 与 ETag 验证。引擎资源位于 /thai-landing/engine/<40位SDK revision>/，该地址可以缓存一年并标记 immutable；升级 SDK 会更换目录。构建脚本移动原引擎目录，必须部署整个 site，包括预压缩的 .gz 文件。发布构建为脚本与 Wasm 使用更紧凑的 gzip，生产静态挂载和本地预览直接发送这些文件；网关已有压缩作为没有预压缩文件时的处理。压缩响应保留 Vary、表示对应的 ETag 和 HEAD 长度，视频 Range 响应不压缩。报告接口使用 no-store。页面和欢迎页保持 Flutter 实现。

报告动画不参与首页下载。生成页从开始就在下半屏显示约 3.02 MB 的原版星球转盘，以半透明、渐隐边缘和触摸穿透轻微叠放进度区域，矮屏适配位置和大小，取消按钮保持可见，静音、内联循环播放；三个阶段和实际生成进度更新时复用同一个视频元素。报告完成后停止循环，当前一轮播完再显示结果。视频结束不能提前判定报告完成。视频请求、自动播放或持续播放失败时，使用同素材约 1.90 MB 的循环 WebP；由浏览器原生图片元素显示，保留位置、遮罩及触摸穿透，避免受 Flutter 图片解码器的循环行为影响。备用动画加载失败也有限重试，持续不可用时显示海报，始终等待实际报告结果。减少动态效果时使用静态画面。静态服务器继续支持视频 Range 请求。

## 原站点与回退

原有 web、api、core、PostgreSQL 和 Redis 容器不由本项目的 Compose 管理。发布本项目时不停止或重新创建它们。网关配置通过 Caddy 校验后热重载；原 Compose 仅增加持久化 Caddyfile 的挂载。

应用版本有问题时，先确认回退版本能读取数据库中的全部报告格式，再进入对应的已验证发布目录，执行 `sudo docker compose up -d --wait` 回退应用镜像，数据目录仍复用同一份。网关修改失败时，发布脚本会恢复原网关配置。

2026-11-11 的 `20261111-181148` 发布将新报告切换为 RoxyAPI 西洋排盘、Qwen 解读，资料说明版本为 `h5-data-use-2`；历史泰式报告保留原计算依据。运行配置新增 `LIFE_ASTROLOGY_PROVIDER=roxy`、`ROXY_ENABLED=true` 及仅保存在服务器的 `ROXY_API_KEY`。数据库中出现西洋报告后，不能直接回退到尚不支持该格式的旧后端；应保留同时支持 `legacy` 和 `western-compact` 的读取能力。失败回退须先停止写入、等待服务退出再检查记录，不能用旧数据库备份覆盖新报告。发布与验证记录位于 `../output/local-release-20261111-1752/deployment-result.json`。

公网推荐入口为 `https://fatehoro.top/`。原 IP 仍可使用 `https://129.226.126.212/thai-landing/?lang=zh`；`Caddyfile.ip` 使用 Let's Encrypt `shortlived` profile 申请免费公网 IP 证书，自动续期依赖现有持久化 `ipplay_caddy_data` 卷。Docker 网关必须在全局设置 `default_sni 129.226.126.212`，否则不发送 SNI 的 IP 客户端会选不到证书。`publish_proxy.py` 在保留其他域名站点的前提下放置全局选项、校验后热重载，遇到其他全局配置会停止而不覆盖。

部署整个 `site`，包括 `.br` 与 `.gz` 文件。发布构建离线生成最高级别 Brotli，服务端根据 `Accept-Encoding` 的质量值选择 Brotli、gzip 或原文件，缺少压缩文件时继续协商回退；保留各表示的 ETag、HEAD 长度与 `Vary`。视频 Range 使用原文件，报告接口仍为 `no-store`。

旧 HTTP 入口继续保留，用于迁移原浏览器的 `astro-life-report-key`：HTML 启动脚本在 Flutter 运行前通过仅当前主机、路径受限、有效期 60 秒的 SameSite=Lax Cookie 转交凭证，不放入 URL；HTTPS 持久化并校验后立即清除 Cookie。原 HTTP 本地存储不删除。Cookie 不可写时不跳转；HTTPS 存储不可写或已有不同有效凭证时返回带 `legacy_http=1` 的原 HTTP 链接，保留两侧原凭证，冲突的旧凭证另存为恢复值。迁移期间不对旧 HTTP 全站强制跳转，也不对 IP 启用 HSTS。
