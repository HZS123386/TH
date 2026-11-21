# FATE 项目目录约定

- APP 源码在 `TH/app`，落地页源码在 `western-astrology-h5 4/web-client`，共用后台在 `TH/backend`。
- 在当前总仓库内开发和提交；脚本通过自身位置定位相邻项目，不写死桌面绝对路径。
- 部署准备使用现有 `western-astrology-h5 4/deploy/prepare_release.py`。本地部署包固定为 `output/deploy/latest`，前一份为 `output/deploy/previous`。
- 如确实需要 Git 工作区，放入 `output/worktrees`；备份放入 `output/archive`。不要再在桌面创建带日期的项目副本。
- 环境密钥、数据库、构建产物和归档不提交 Git；源码目录中的 `lib/data` 是业务源码，不能被数据目录忽略规则排除。
- 迁移时保留的旧桌面路径仅有迁移提示，不是源码位置。

- 唯一开发和启动目录是 `C:\Users\32668\Desktop\海外-玄学`，原 `C:\Users\32668\Desktop\git\TH-H` 已迁出，不得再在那里新增或修改项目代码。
- H5 真实入口为 `western-astrology-h5 4/web-client/lib/main.dart`，App 入口为 `TH/app/lib/main.dart`，共用后端入口为 `TH/backend/app/main.py:create_app`。
- 统一启动使用根目录下的 `node TH/scripts/dev.mjs`，继续修改现有模块和调用链，不新增同功能原型、覆盖层、代理入口或运行时补丁。
- 本地配置在 `TH/.env`。业务库由唯一的 PostgreSQL `DATABASE_URL` 指定，启动前核对当前业务库及迁移版本。`TH/data/` 保留地点索引及本地资源。禁止输出密钥或把配置、业务数据及备份提交 Git。

## 支付合并约定

- 保留手机号建单、官方收银台、服务端查单、到账核对及报告解锁链路；创建订单、点击按钮、返回页面或未核验通知均不代表付款成功。
- 测试使用隔离数据库和外部服务替身；没有用户另行授权时不创建真实支付订单、不付款。
- 支付凭据保留在本机环境配置，当前数据库路径保持不变，禁止把密钥或业务数据提交 Git。
- 精确修改源码并保留无关改动，测试通过后只针对新改动或新问题复测，交付时区分本地验证和线上生效。
