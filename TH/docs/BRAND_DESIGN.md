# ดวงใจ / 星心 · 品牌更新

2026-11-05。根据用户要求，调整原 WANJAI 图标、名称和副标题，保持现有米白、砖红、古金色主题。

## 展示名

| 语言 | 名称 | 副标题 |
| --- | --- | --- |
| 简体中文 | 星心 | 泰式占星 · 心有所依 |
| 泰语 | ดวงใจ | โหราศาสตร์ไทย คู่ใจทุกวัน |
| 美国英语 | Starheart | Thai astrology. Daily guidance. |
| 越南语 | Tâm An | Chiêm tinh Thái · Bạn đồng hành |

四个名称是同一产品在不同语言下的展示名，不是逐字直译。用当地语言可读的名称配上明确的产品副标题，表达泰式占星与每日生活陪伴的定位。泰语词形也呼应原产品的“ดวง / ใจ”主题。未进行商标注册或泰国本地用户的品牌信任度研究，设计不声称能够保证信任或预测效果。

## 图形

原创五瓣莲花、上方星芒和不闭合环线，配稳重的砖红和古金色。莲花提供泰国文化联系，星芒和环线指向占星；图案没有复制寺院、政府或宗教机构的徽记，没有寺院认证、开光或效果保证文字。

选用莲花作为文化线索的依据：[Thailand Foundation, Thai-style Offerings](https://thailandfoundation.or.th/thai-style-offerings/) 介绍了莲花等花卉在泰国佛教供奉中的使用；[Rab Bua: Thailand’s Lotus Throwing Festival](https://thailandfoundation.or.th/th/rab-bua-thailands-lotus-throwing-festival/) 介绍了莲花与当地信仰、社区习俗的联系。这些资料支持文化关联，不构成对本产品的宗教背书。

## 实现

- `src/lib/brand.ts` 保存统一矢量路径，供 React、SVG 导出和 Canvas 分享卡共用。
- `BrandMark.tsx` 渲染标志；`BrandLockup.tsx` 处理字标、大小和副标题。
- 四语言 JSON 的 `brandName/brandTagline/brandDescription` 等字段由既有 i18next 全局切换。
- 桌面侧栏、手机页头、首次语言选择、页面眉题、聊天署名、消息预览、个人页面、页脚、分享卡、浏览器标题和 description 已改用本地展示名。
- 浏览器图标同步换成高对比莲花星芒，使用版本化 URL 避免旧图缓存。
- 排盘规则 ID、数据库、会话键、历史记录及原始可行性材料保留原技术标识，不对已有用户资料做改名迁移。
- 系统提示中的品牌名随回复语言确定；原有聊天历史不重写。

## 矢量资产

运行 `pnpm build:brand`，生成 `public/brand/lotus-star.svg`、浅色版及四份 `brand-{locale}.svg`，并更新 favicon。脚本依赖 Node 的类型擦除能力，与项目要求的 Node 22.12+ 兼容。

正式使用的 React 标志与导出资产均来自同一组路径。图标为代码原生 SVG，放大不失真；没有远程字体、图片或图标服务依赖。

## 检查

检查四语言切换后的名称、副标题、HTML语言、浏览器标题与meta描述；桌面和手机均截图检查字标与换行，分享卡下载使用当前语言品牌名。品牌修改不改变排盘算法，计算验证记录仍以 `GITHUB_INTEGRATION.md` 为准。
## 追加界面纹样

`src/components/ThaiSkyPattern.tsx` 为原创细线星空纹样：泰文十二星座名、浅金双环、星月和小星座连线，用于生辰页与运势首页顶部，配合柔和金色光晕。它是无交互的装饰性 SVG，使用 `aria-hidden`，不冒充个人计算盘，不加载外部图片。正文仍采用清晰的米白、砖红与深色文字。

