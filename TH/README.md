# ดวงใจ / 星心 · 泰国本地生活与占星陪伴

当前独立测算页已改为泰式占星：访问 `/thai-test`，原 `/bazi-test` 链接也进入该页面，或从右上角菜单和“我的”进入“泰式占星解读”。按本命星盘、全年运势、财富、感情、事业、家庭六个主题计算实际泰式宫位与宫主星，再生成各自的解读和行动建议。生日、准确出生时间、出生地和时区参与计算，全年主题使用所选年份逐日行运；页面和导出随系统语言切换。说明与真实接口验收见 [THAI_READING_TESTING.md](docs/THAI_READING_TESTING.md)。

原Roxy八字工具保留于 `/tools/bazi`，仍可通过探索模块进入，不展示原始JSON与计算依据入口。GitHub本地及双源对照仍可通过验收脚本使用。Roxy密钥仅保存在服务端；启用后的新档案八字与八字聊天使用Roxy，泰式引擎继续独立运行。操作、额度和准确性测试方法见 [ROXY_BAZI_TESTING.md](docs/ROXY_BAZI_TESTING.md)。下文旧接入记录中的“没有接通Roxy商业接口”描述属于本次接入之前的状态。

界面品牌已更新为原创莲花星芒标记，展示名随语言切换：中文「星心」、泰语「ดวงใจ」、英语「Starheart」、越南语「Tâm An」。副标题、聊天署名、分享卡和浏览器标题同步切换。品牌设计与可导出矢量资产见 [docs/BRAND_DESIGN.md](docs/BRAND_DESIGN.md)；项目原有 WANJAI 技术标识和数据键保持兼容。

按提供的 WANJAI 离线 App 与可行性报告改造的本地项目，现已对照 GitHub JY 分支移植页面及交互。主界面采用米白、砖红、黄铜金与鼠尾草绿；桌面与移动端统一为 JY 的居中 App 布局和“运势 / 星盘 / 聊聊 / 好物 / 我的”底部五栏。首次打开保留本地四语言弹窗，确认后记住语言，之后可在“我的”中再次打开；Logo 和生辰滚轮也保留本地实现。使用 React 18、TypeScript、Tailwind、pnpm、Vitest 与 FastAPI / SQLite 技术栈。合并来源、页面对应、服务衔接与验收步骤见 [docs/JY_MERGE.md](docs/JY_MERGE.md)。

## 快速开始

需要 Node.js 22.12+、pnpm 11、Python 3.12。首次运行：

```powershell
pnpm install
pnpm setup:api
pnpm dev
```

打开 [本地页面](http://127.0.0.1:5173)，API 文档位于 [FastAPI Docs](http://127.0.0.1:8000/docs)。开发时 Vite 将 `/api` 代理到 8000 端口。按 Ctrl+C 停止前后端。

默认不需要 `.env` 或模型密钥。首次打开先确认语言，再填写出生年月日（必填）；具体时分和城市均为选填，也可明确勾选“不记得确切时间”。完成生日后即可免费查看今日、本周、本月运势，不要求登录，没有年度入口。访客资料保存在此浏览器的 `wanjai.birth`，计算时发送本地 API，不写入账号数据库；刷新后无需重复填写，可在“我的”中修改。

右上角“登录”（泰语为“เข้าสู่ระบบ”）提供本地测试账号。没有档案的账号可预填当前访客生辰，由用户确认保存后绑定；已有账号优先恢复其服务端档案，不用访客资料覆盖。账号修改和退出不会把私人档案写回访客资料。

出生日期、时间、国家与城市、时区使用米白砖红主题的滚轮弹窗，支持触摸上下滑动、鼠标滚轮或拖动，以及方向键操作；点击“完成”才回填，关闭或按 Escape 放弃本次修改。日期限制为 1901 年起至出生地今天，闰年与每月天数自动联动；可切换公历／佛历年份，存储统一使用公历。出生地先内置中国、泰国、越南、美国的常用城市，选择城市会带入 IANA 时区；其他地点可手动填写，并单独搜索和选择时区。城市名以稳定标识保存，显示名称随全局语言变化，常用城市之外可展开“泰式排盘地点与坐标”，搜索离线目录或手动提供经纬度；未知地点不会默认套用曼谷。

再次登录同一账号会恢复原来的生辰、命盘、对话和记忆，已有档案时不再显示建档引导。未完成建档就退出的账号，下次登录继续建档。浏览器会话令牌保存在 localStorage；账号、密码摘要和生辰资料保存在 `data/sabai.db`。清除浏览器数据、会话过期或换浏览器后，可用原账号密码重新登录。旧版匿名会话仍有效时，创建账号会将该匿名用户已有资料一起绑定，避免丢失。

这些账号目前只用于本地开发体验，`production` 模式关闭注册、登录与开发会话。未实现找回密码、邮件验证和正式账号生命周期。LINE / LIFF 身份接入仍未实现。

## 本次实现

新增泰式引擎、个人盘和验证报告，详见 [docs/GITHUB_INTEGRATION.md](docs/GITHUB_INTEGRATION.md)。现已从 ai-spiritual-companion 固定提交移植温和角色、回答前召回／成功后记录、语义检索失败回退和按用户限额的核心流程，适配现有 FastAPI／SQLite 与本地泰式工具；不调用付费 RoxyAPI，不需要它的密钥。源码归属、配置和验收见 [docs/CHAT_INTEGRATION.md](docs/CHAT_INTEGRATION.md)。另已接入 OpAstro 免费开源的周期事件筛选与去重，用已有 Qwen 写四语言日、周、月解读，保留泰式计算；支持账号隔离、缓存及失败回退，详见 [docs/OPASTRO_INTEGRATION.md](docs/OPASTRO_INTEGRATION.md)。

- 泰式สุริยยาตร์本命与上升、十颗星体、整星座十二宫和宫主、九分盘、三分盘、ทักษา、泰历与此刻行运。泰式圆盘结构与标记按 GitHub 引擎示例实现，使用个人计算数据。
- 首页今日、本周、本月从出生资料与实际行运位置生成四主题规则解读。生日简版保留未知时间和地点的范围；完整资料使用泰式本命上升与整宫制。规则、取样、边界与复现见 [docs/FORTUNE_RULES.md](docs/FORTUNE_RULES.md)。今日陪伴、七步路径和长篇报告的正文仍是明确标注的编辑建议。
- 10 个具体问题、20 种情况、20 条追问；所选情况改变行动路径，并作为数据带入模型对话。未发送草稿按账号隔离，保存在当前浏览器会话中。
- ฿99 专题方案：两条路径、两份模板、两种分支；฿199 六章人生报告：一章完整试读与模拟解锁。没有真实订单或扣款，模拟记录不是支付权益。
- 七步陪伴按曼谷日期记录，每个问题每天一次，支持反馈、暂停、继续与撤销；今日心情、作息与配色为编辑建议，不是幸运结果保证。
- 回访频率、偏好时间、星语消息与提醒预览；未连接 LINE，不发送真实推送。
- 六款示例好物、风格／分类／预算筛选、详情与收藏；支持规格、数量、模拟结算及账号体验记录，没有真实库存、发货或扣款。
- 我的生辰、确认记忆、心愿、大字阅读、语言切换；分享卡可保存为 PNG，由用户自行分享。
- 已登录用户通过 `GET /api/companion`、`PUT /api/companion` 将陪伴状态保存到账号；访客偏好保存在浏览器。仅在访客主动选择“登录继续聊天”时接续其所选问题、情况和草稿，不自动复制心愿或体验订单。退出及发送问题前等待保存请求完成，当前情况、心愿和相关偏好可进入模型上下文。

迁移范围与来源见 [docs/WANJAI_MIGRATION.md](docs/WANJAI_MIGRATION.md)。原框架能力继续保留：

- 模块目录与开放状态：泰式占星与八字四柱已开放，西洋占星和梦境探索有可浏览的筹备入口。后端 `modules.py` 集中登记能力，`/api/modules` 与 `/api/config` 提供给前端。
- 出生档案、真实四柱计算、可见五行计数、资料版本。
- 本地账号注册、登录、退出、服务端账号与生辰绑定；首次登录建档，已有档案直接恢复。
- 生辰时间明确区分上午／下午，并按时分保存为出生地本地 24 小时制；未知时间使用 null，不自动假定 09:00 或中午。
- 公历日期和 IANA 时区校验，默认 `Asia/Bangkok`；拒绝夏令时重复或不存在的出生时刻。
- 未知出生时间只保留当日稳定的柱，时柱留空。
- SSE 连续问答、停止生成、错误提示；成功后将完整问答成对写入数据库。
- 聊天中确认保存自己的陈述，查看、修改和删除确认记忆；每人最多20条、每条500字。每个成功对话另存带计算依据的档案，供跨会话回顾；可选向量检索按主题召回，未配置时按日期回顾。
- 修改档案重算并清空旧对话，确认记忆保留；清空对话也保留记忆。
- Mock、百炼Qwen、OpenAI、DeepSeek、Kimi的流式适配。新增陪伴协作模式（`DEFAULT_PROVIDER=companion`）：Qwen起草、Kimi依据同一份用户资料与计算结果校对润色，统一输出一条完整回答；复核不可用时保留完整Qwen回答，并在回答依据中记录单模型状态。两阶段完成后再展示，通常产生两次模型调用。单模型模式保留直接流式和失败提示。每条回复可展开生辰版本、运势日期范围、回忆模式与实际模型流程。
- i18next / react-i18next 四语言界面、首次语言选择、全局即时切换、偏好持久保存；手机与桌面布局。本地加载泰文字体，无需访问 Google Fonts。
- 服务端会话摘要、用户数据隔离、请求大小限制、简单限流与每用户并发保护。

设计文档中的“已实现”描述不是本项目的交付记录。本框架暂未实现西洋占星引擎、LINE / LIFF 登录与 webhook、主动推送、解梦、手相、支付、密码找回或账号删除。语义记忆的可选适配已实现，真实向量服务仍待密钥联调。`APP_ENV=production` 会关闭本地账号入口、开发登录和已有会话；需要接入正式身份认证后才能作为真实用户服务发布。

## 模型配置

复制配置模板（PowerShell）：

```powershell
Copy-Item .env.example .env
```

在 `.env` 设置提供方的 `API_KEY`、`BASE_URL`、`MODEL`，重启后页面的模型菜单会启用对应选项。例如 DeepSeek 对应 `DEEPSEEK_API_KEY`、`DEEPSEEK_BASE_URL`、`DEEPSEEK_MODEL`。`BASE_URL` 填写兼容接口的基地址，不包含 `/chat/completions`；Qwen 使用账号工作空间的实际兼容地址。模型名按账号实际权限填写，框架不猜测当前可用型号。

默认 `DEFAULT_PROVIDER=mock`。真实模型未配置时返回 503，不会在请求失败后自动切换模型。密钥只保存在后端，不能使用 `VITE_` 前缀。模型适配采用 Chat Completions 协议；[OpenAI 官方接口文档](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)说明了流式调用及输出参数。仅支持其他协议的模型需要新增适配器。真实模型会产生上游调用费用，本次没有使用真实密钥验证。

界面右上角的语言按钮可重新打开选择页，选择会同步到页面、导航、登录、建档、校验错误、日期显示和后续模型回答。应用使用 `zh-CN`、`th-TH`、`vi-VN`、`en-US`；API 与旧档案内部兼容 `zh`、`th`、`vi`、`en`，其中 `en` 始终表示美式英语。首次预选参考浏览器语言，需要用户确认；之后浏览器记住选择。四份 JSON 文案随应用本地打包，缺失文案由 i18next 回退到美式英语。

登录后使用 `PUT /api/preferences/language` 单独保存账号语言，不增加命盘 revision、不重算生辰、不清空对话或确认记忆。每个请求通过 `Accept-Language` 指定当前应用语言，服务端错误和流式回答使用该语言。已有聊天内容作为历史记录保留原文。生辰表单不再提供独立的另一套回复语言设置。

## 计算口径

主体系使用 [thai-astrology](https://github.com/kongesque/thai-astrology) **0.3.2**，固定สุริยยาตร์、日出参照、Anto升起时长、whole-sign宫制、历史曼谷+06:42:04行星框架；ทักษา按06:00换日，本版不另换周三夜间罗睺规则。时间未知不生成完整个人盘、上升、宫位或ทักษา；首页生日简版仅保留可计算的泰式太阳参考范围，不假定一个出生时刻。地点无法确定时不生成完整盘。泰国流派不同，海外上升也需同口径核验。完整功能、许可、边界与来源见 [GitHub接入记录](docs/GITHUB_INTEGRATION.md)。

运行 `pnpm verify:thai` 可复现150项计算检查，查看 [本地验证报告](http://127.0.0.1:5173/reports/thai-validation.html?lang=zh)。独立获取的4个USNO日出样本最大误差约0.337分钟；行星与上升尚缺同流派独立对照，未来事件预测准确率未建立。软件通过率不能称作算命准确率。

以下是独立辅助八字工具的口径：

输入出生地当地民用时间，转换为 `Asia/Shanghai` 后交由 [lunar-python](https://github.com/6tail/lunar-python) 1.4.8 计算，日柱使用 `sect=2`。未校正经度或真太阳时；地点文字只用于记录。时间未知时比较当地当天的起止时刻，仅保留一致的年、月、日柱，时柱为空。以曼谷为例，当地一天跨越两个北京日期，因此日柱可能留空。

表单可切换公历与现代泰国佛历年份，保存时统一换算为公历。五行计数只统计已确认柱的可见干支，不等于藏干权重、旺衰、喜用神或幸运色。中国四柱计算与泰式占星是两套独立方法。默认聊天使用泰式工具事实；明确询问八字时才带入四柱。

## 目录与扩展点

```text
src/
  components/       # 界面组件，PascalCase 文件名
  lib/api.ts        # JSON API、会话与 SSE 消费
  lib/i18n.ts       # i18next 初始化、全局语言 Hook 与回退
  lib/languages.ts  # 支持的语言与地区、偏好兼容
  locales/          # zh-CN / th / vi / en-US 完整 JSON 文案
  App.tsx           # 页面、会话和交互状态
backend/app/
  main.py           # 路由、鉴权、SSE、限流和并发保护
  modules.py        # 能力注册与模块开放状态
  schemas.py        # 输入契约
  accounts.py       # scrypt 密码摘要与验证
  i18n.py           # 四语言 API 校验、错误与响应语言
  bazi.py           # 确定性排盘
  storage.py        # SQLite 仓储
  providers.py      # 上下文、Mock 和模型流式适配
  config.py         # 服务端环境配置
backend/tests/      # 后端集成和协议测试
e2e/                # 桌面与手机浏览器流程
```

下一步接入 LINE 时，将服务端验证后的 LINE subject 映射到内部用户，再发放本应用会话；不信任前端传来的 userId。泰式引擎已通过独立适配器接入，登记 method、calculation_version，并扩展了结果组件和对话上下文；尚未接入的西洋星历、解梦和手相仍保持 planned。已有出生档案、用户会话与确认记忆仓储继续复用。

本地账号接口：`POST /api/auth/register`、`POST /api/auth/login`、`GET /api/auth/me`、`POST /api/auth/logout`。注册和登录只接受 username、password，生辰接口不接受客户端指定其他用户 ID。密码使用独立随机盐与 scrypt 摘要存储，参数采用 [OWASP 的 scrypt 配置](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html#scrypt)中的 N=2^15、r=8、p=3；使用 Python 标准库实现，摘要计算在后台线程执行，最多同时执行两次。

## 验证与构建

```powershell
pnpm test
pnpm test:api
pnpm check:api
pnpm build
pnpm test:e2e
```

浏览器测试在 Windows 默认使用已安装的 Edge。其他平台先运行 `pnpm exec playwright install chromium`；也可用 `PLAYWRIGHT_CHANNEL` 指定浏览器渠道。测试使用独立的 `data/e2e.db`，不读取日常开发数据库；前端与 API 分别使用 5174、8001 端口，并关闭 API 自动重载。日常开发服务使用 5173、8000，可与测试并行运行；请保持测试端口空闲。

构建后可只运行后端，由 FastAPI 提供 `dist` 中的页面：

```powershell
pnpm build
node scripts/python.mjs -m uvicorn backend.app.main:create_app --factory --host 127.0.0.1 --port 8000
```

这是单进程开发框架。SQLite、进程内锁和限流尚未验证多实例或正式容量；部署升级时需配套共享存储、正式认证和数据生命周期。详细验收结果见 [docs/VALIDATION.md](docs/VALIDATION.md)。
