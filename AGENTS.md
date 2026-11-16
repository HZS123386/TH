# FATE 项目目录约定

- APP 源码在 `TH/app`，落地页源码在 `western-astrology-h5 4/web-client`，共用后台在 `TH/backend`。
- 在当前总仓库内开发和提交；脚本通过自身位置定位相邻项目，不写死桌面绝对路径。
- 部署准备使用现有 `western-astrology-h5 4/deploy/prepare_release.py`。本地部署包固定为 `output/deploy/latest`，前一份为 `output/deploy/previous`。
- 如确实需要 Git 工作区，放入 `output/worktrees`；备份放入 `output/archive`。不要再在桌面创建带日期的项目副本。
- 环境密钥、数据库、构建产物和归档不提交 Git；源码目录中的 `lib/data` 是业务源码，不能被数据目录忽略规则排除。
- 迁移时保留的旧桌面路径仅有迁移提示，不是源码位置。

## 支付合并约定

- 保留手机号建单、官方收银台、服务端查单、到账核对及报告解锁链路；创建订单、点击按钮、返回页面或未核验通知均不代表付款成功。
- 测试使用隔离数据库和外部服务替身；没有用户另行授权时不创建真实支付订单、不付款。
- 支付凭据保留在本机环境配置，当前数据库路径保持不变，禁止把密钥或业务数据提交 Git。
