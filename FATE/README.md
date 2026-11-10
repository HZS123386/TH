# FATE 免费西洋占星首版

FATE H5 使用 FastAPI、PostgreSQL 和独立报告 Worker。用户选择出生日期、当地时间与城市后，可以查看西洋星盘的解析流程和解锁页面。首版的解读依据盘面位置和对应的泰语规则，出生时间未知时返回日期级结果。

## 入口

| 组件 | 入口 |
|---|---|
| H5 | h5/src/main.tsx，生产构建由 FastAPI 同源服务 |
| 后端 | backend/fate/main.py，报告处理入口为 backend/fate/worker.py |
| 数据库 | backend/alembic.ini，业务数据使用 PostgreSQL |

## 启动 H5 和共用后台

复制 .env.example 为 .env，填写 FATE_DB_PASSWORD，并用同一个密码更新 FATE_DATABASE_URL。填入已开通西洋本命盘的 FATE_ROXY_API_KEY、至少 32 字符的随机 FATE_IP_HASH_KEY、正式支持邮箱 FATE_SUPPORT_EMAIL。密钥保存在 .env 或部署平台密钥管理中。

在 FATE 目录运行：

    docker compose up -d --build
    docker compose logs -f api worker

H5 地址为 http://127.0.0.1:8710，隐私页为 /privacy，支持页为 /support，配置和数据库检查为 /healthz。发布使用 HTTPS 反向代理，限制请求体和请求速率，关闭含个人资料的请求体记录。将 FORWARDED_ALLOW_IPS 设为实际的反向代理来源地址，使限流按真实客户端区分。使用项目 Roxy 账号完成真实测算验证后再投放。

如使用已有 PostgreSQL，在 backend 目录配置相同的环境变量，运行 python -m alembic upgrade head 后，分别启动 uvicorn fate.main:app --port 8710 和 python -m fate.worker。

使用 H5 调试服务器时，在 h5 运行 npm ci 与 npm run dev，Vite 将 /api 转发到本地 8710。生产构建用 npm run build。

## 投放效果

链接使用 utm_source 与 utm_campaign。H5 的访问、提交和结果可见分别记录一次，按浏览器标签会话去重。提交人数和结果可见人数按同一访问会话统计，不代表跨设备独立用户。报告接口与事件均不会将出生资料发送到广告平台。

    docker compose exec api python -m fate.metrics --days 7

## 数据与外部服务

地点索引来自 GeoNames cities15000，按 Creative Commons Attribution 4.0 许可使用。数据来源 https://www.geonames.org/ ，下载 https://download.geonames.org/export/dump/cities15000.zip 。更新索引可运行 python backend/scripts/build_places.py 路径/cities15000.zip。更新城市索引后，用 python backend/scripts/build_places.py --regions 路径/birth-locations.sqlite3 从 TH-H 的公开地点索引补充中泰行政区及译名。

西洋排盘使用 RoxyAPI 的 Western Natal Chart，采用热带黄道和 Whole Sign 宫制。计算仅发送当地出生日期、时间、城市坐标与当时的时区偏移。访客报告以随机访问密钥保护，24 小时后不可访问，Worker 定期清理。报告完成或终止后会移除排盘输入。H5 投放汇总的会话事件保留 30 天。
