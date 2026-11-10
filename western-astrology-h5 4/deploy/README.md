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

Flutter 版预加载本地 WebP 主图，首帧等待主图解码完成，避免先显示缺少主图的页面。原始图片及其他分辨率素材继续保留。

Flutter 版使用本地 Noto Sans Thai；完整中文字体只在中文页面和切换中文时加载。泰文首页仅使用小型语言标签补充字库。字体授权和 Flutter 渲染资源随构建提供，不请求 Google Fonts 或 Flutter 公共 CDN。PDF 使用独立字体。

Flutter 的 `main.dart.mjs`、`main.dart.wasm`、引导文件和资源清单使用稳定名称，当前网关模板统一设置 `Cache-Control: no-cache`，通过 ETag 重新验证，避免发布后混用旧脚本或字体。报告接口继续禁止缓存。网关保留 zstd/gzip 压缩；本次仅更新本地部署模板，未更改服务器入口。

报告动画不参与首页下载。点击生成立即显示静态首帧和文字，视频就绪后静音循环。视频约 1.67 MB，进度由服务端真实快照更新，尊重减少动态效果设置。静态服务器需要支持视频 Range 请求。

## 原站点与回退

原有 web、api、core、PostgreSQL 和 Redis 容器不由本项目的 Compose 管理。发布本项目时不停止或重新创建它们。网关配置通过 Caddy 校验后热重载；原 Compose 仅增加持久化 Caddyfile 的挂载。

应用版本有问题时，可进入先前已经验证的发布目录，执行 `sudo docker compose up -d --wait` 回退应用镜像，数据目录仍复用同一份。网关修改失败时，发布脚本会恢复原网关配置。

当前按用户选择使用公网 IP 和 HTTP。以后启用域名时，应先完成 DNS 解析，再增加对应域名的 HTTPS 站点。
