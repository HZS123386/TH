# 腾讯云落地页部署

部署目标为 `ubuntu@129.226.126.212`。使用当前本地落地页及相邻的 `TH` 后端源码，保留服务器已有的 `ipplay.top` 网站。

- 访问入口：`http://129.226.126.212/thai-landing/?lang=zh`
- 健康检查：`http://129.226.126.212/health`
- 应用容器：`astro-life-report`，Python 3.12、Node.js 24、单个 Uvicorn worker。
- 当前发布目录：`/opt/astro-life-report/current`，指向 `releases/` 中的版本。
- 持久化数据：`/opt/astro-life-report/shared/data`，包括地点索引和新生成的报告数据库。
- 服务端配置：`/opt/astro-life-report/shared/runtime.env`，仅服务器 root 可读。
- 入口配置：`/opt/astro-life-report/shared/Caddyfile`，沿用现有 Caddy 网关，另外增加公网 IP 站点。
- 网关修改前的备份：`/opt/astro-life-report/shared/backups/ingress-*`。

当前保留原有点击解锁逻辑，不接入真实收款。TH 的本地开发登录入口在 production 环境关闭，公网入口只转发落地页、地点查询、人生报告接口和健康检查。

## 日常查看

通过 SSH 登录服务器后执行：

```sh
cd /opt/astro-life-report/current
sudo docker compose ps
sudo docker compose logs --tail 80 app
```

应用设置了自动重启策略。服务器的 Docker 服务已启用开机启动。请保留 `shared/data`，不要用开发机的个人报告数据库覆盖它。

## 制作新版本

先在落地页目录执行 `pnpm build`，再运行 `deploy/prepare_release.py`。生成结果在被 Git 忽略的 `output/deploy/` 下。

发布包包含后端、排盘脚本及库、`TH/src/content`、`TH/src/locales`、`TH/src/data` 中的运行资源，以及落地页 `site` 构建目录。报告校验代码会读取这些语言资源，不能只复制 Python 文件。

`runtime.env` 与应用压缩包分开生成和上传，不进入 Docker 构建上下文。打包程序会检查构建文件中是否包含本机已配置的密钥，并排除原有用户数据库。地点索引单独复制，后续版本复用服务器已有文件。

首次部署依次使用 `stage_server.sh`、`start_server.sh` 和 `publish_proxy.py`。后续更新只需构建和启动新应用版本。需要修改已有 IP 入口时，向网关脚本额外提供上个版本的 `Caddyfile.ip` 路径；只有旧配置逐字匹配时才替换该站点，避免重复添加或改动其他网站。

## 首屏资源

本地构建现已切换为 Flutter Web。发布时继续复制 `site/`，不需要在服务器安装 Flutter；后端挂载 `/thai-landing/` 的方式和报告数据库位置保持一致。构建必须使用相同的 base 路径。`.mjs` 应返回 JavaScript MIME，`.wasm` 应返回 `application/wasm`，字体和视频须能从同源访问。下述旧版响应式图片方案仅适用于历史 React 构建；新版使用本地 Flutter 渲染引擎与字体，实际校验记录见 `../docs/FLUTTER_H5_MIGRATION.md`。

Flutter 版首屏只预加载欢迎页主图，并提前低优先级读取资源及文案清单。表单和主题图板在用户开始进入首页时构建，在原人物过渡期间准备，不参与欢迎页首帧。图片等待最多 700ms；静态欢迎页在收到真实绘制通知前继续请求帧，避免引擎批量上报帧计时造成加载层停留。HTML 加载状态由实际首帧完成后移除，失败或慢网时提供重试。

中文首屏使用 348 KB 精简 OTF；常用字库在进入表单后预备，完整字库只在后续文本需要时读取。符号字体约 24 KB，泰文首页不加载中文字库。Python 静态服务显式注册 font/otf、font/ttf、font/woff2 MIME，让网关可以压缩字体响应。PDF 字体独立保留。

Flutter 的入口、业务文件和资源清单继续使用 no-cache 与 ETag 验证。引擎资源改用 /thai-landing/engine/<40位SDK revision>/，该地址可以缓存一年并标记 immutable；升级 SDK 会更换目录。构建脚本移动原引擎目录，必须部署整个 site。网关保留 zstd，并将 gzip 设为 6 级；本地 Node 预览也对 Wasm、脚本和字体等启用 gzip。压缩响应保留 Vary 与条件缓存验证，视频 Range 响应不压缩。报告接口使用 no-store。

报告动画不参与首页下载。生成页从开始就在下半屏显示约 3.02 MB 的原版星球转盘，以半透明、渐隐边缘和触摸穿透轻微叠放进度区域，矮屏适配位置和大小，取消按钮保持可见，静音、内联循环播放；三个阶段和实际生成进度更新时复用同一个视频元素。报告完成后停止循环，当前一轮播完再显示结果。视频结束不能提前判定报告完成；播放失败使用海报并继续等待实际结果，减少动态效果时使用静态画面。静态服务器继续支持视频 Range 请求。

## 原站点与回退

原有 web、api、core、PostgreSQL 和 Redis 容器不由本项目的 Compose 管理。发布本项目时不停止或重新创建它们。网关配置通过 Caddy 校验后热重载；原 Compose 仅增加持久化 Caddyfile 的挂载。

应用版本有问题时，可进入先前已经验证的发布目录，执行 `sudo docker compose up -d --wait` 回退应用镜像，数据目录仍复用同一份。网关修改失败时，发布脚本会恢复原网关配置。

当前按用户选择使用公网 IP 和 HTTP。以后启用域名时，应先完成 DNS 解析，再增加对应域名的 HTTPS 站点。
