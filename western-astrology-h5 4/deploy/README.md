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

顶部主图使用 450、900、1199 像素三档 WebP，浏览器按显示宽度和像素密度选择，预加载与页面使用相同的 srcset。PNG 留作不支持 WebP 的浏览器回退。后续更换肖像时，需要同步生成三个 WebP 文件。

中文使用设备本身的中文字体；泰文使用随页面提供的 Noto Sans Thai WOFF2 字体及 OFL 授权文件，不再向 Google 请求网页字体。PDF 仍使用原有完整中文和泰文字体。

带内容哈希的图片、脚本、样式、字体与视频可缓存一年；HTML 每次使用时重新验证，报告接口禁止缓存，避免报告进度和权限状态被旧响应覆盖。

报告动画在用户开始填写表单时预载，不参与首屏下载。点击生成后立即显示动画首帧，视频就绪时直接接续播放；弱网下首帧会有轻微呼吸效果，文字与画面同时出现。动画视频保留原有画面和时长，压缩至约 1.67 MB。进度仍依据服务端实际生成内容更新，尊重系统减少动态效果的设置。

## 原站点与回退

原有 web、api、core、PostgreSQL 和 Redis 容器不由本项目的 Compose 管理。发布本项目时不停止或重新创建它们。网关配置通过 Caddy 校验后热重载；原 Compose 仅增加持久化 Caddyfile 的挂载。

应用版本有问题时，可进入先前已经验证的发布目录，执行 `sudo docker compose up -d --wait` 回退应用镜像，数据目录仍复用同一份。网关修改失败时，发布脚本会恢复原网关配置。

当前按用户选择使用公网 IP 和 HTTP。以后启用域名时，应先完成 DNS 解析，再增加对应域名的 HTTPS 站点。
