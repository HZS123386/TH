'use strict';

const $ = (selector) => document.querySelector(selector);
const esc = (value) =>
  String(value ?? '').replace(
    /[&<>"']/g,
    (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char],
  );
const number = (value) => Number(value || 0).toLocaleString('zh-CN');
const duration = (value) => value == null ? '未采集' : (Number(value) / 1000).toFixed(1) + ' 秒';
const visitLink = (id) => id ? `<button class="button" data-visit="${esc(id)}">查看访问轨迹</button>` : '';
const money = (value) =>
  (Number(value || 0) / 100).toLocaleString('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
const date = (value) =>
  value
    ? new Date(Number(value) * 1000).toLocaleString('zh-CN', {
        timeZone: 'Asia/Shanghai',
        hour12: false,
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      })
    : '未记录';
const fullDate = (value) =>
  value
    ? new Date(Number(value) * 1000).toLocaleString('zh-CN', {
        timeZone: 'Asia/Shanghai',
        hour12: false,
      })
    : '未记录';
const short = (value) =>
  String(value || '').length > 16
    ? String(value).slice(0, 8) + '…' + String(value).slice(-4)
    : String(value || '—');
const icons = {
  overview:
    '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  visits:
    '<circle cx="9" cy="8" r="3"/><path d="M3 21v-3a6 6 0 0 1 12 0v3M16 5a3 3 0 0 1 0 6M18 15a5 5 0 0 1 3 5"/>',
  'visit-funnel': '<path d="M3 5h18M5 10h14M7 15h10M9 20h6"/>',
  'page-diagnostics': '<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/>',
  'ad-funnel': '<path d="M3 5h18l-7 8v5l-4 2v-7z"/>',
  reports: '<path d="M14 3H5v18h14V8zM14 3v6h5M8 13h8M8 17h5"/>',
  orders: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18M7 15h3"/>',
  calls: '<path d="M3 12h4l3-8 4 16 3-8h4"/>',
  issues: '<path d="m12 3 10 18H2zM12 9v5M12 17v1"/>',
  audit: '<path d="M4 11a8 8 0 1 1 2 6M4 5v6h6M12 7v5l3 2"/>',
  sources:
    '<ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v7c0 4 16 4 16 0V5M4 12v7c0 4 16 4 16 0v-7"/>',
};
const icon = (name) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name] || icons.reports}</svg>`;
const views = {
  overview: ['数据总览', '从访问到报告交付，查看每一个关键环节。'],
  visits: ['访问与来源', '查看每次访问的填写进度、前台停留和最后记录。'],
  'page-diagnostics': ['页面停留与错误', '比较 H5 各页的前台停留时间，查看出错的环节和已记录的原因。'],
  'visit-funnel': ['H5 访问漏斗', '查看从填写资料到点击 LINE 的各步数据。'],
  'tarot-activity': ['塔罗访问统计', '查看塔罗各页面的进入人数、进入次数、停留时间和关键操作。'],
  'ad-funnel': ['广告转化', '查看带投放标签的访客，从进入 H5 到点击 LINE 的各步人数。'],
  reports: ['报告管理', '查看生成状态、解锁权限，追踪每一份报告。'],
  orders: ['订单与支付', '区分订单创建、到账核验和报告权益。'],
  calls: ['模型调用', '查看每次请求的模型、Token、耗时与校验结果。'],
  issues: ['失败与异常', '区分当前业务异常与历史失败尝试，定位需要跟进的记录。'],
  audit: ['操作记录', '管理员的每次处理都有时间、原因和结果。'],
  sources: ['数据来源与口径', '知道数据从哪里来，也知道每个数字如何计算。'],
  'line-contacts': ['LINE 报告发放', '查询占星或塔罗领取编号，处理 LINE 发放。'],
};
const visitPages = {
  welcome: '欢迎页', birth_form: '资料填写页', consent: '数据使用确认', history: '历史报告列表',
  privacy: '隐私说明页', support: '帮助与联系页', generating_preview: '免费报告生成中',
  generating_full: '完整报告生成中', report_loading: '报告加载页', preview_report: '免费报告 / 解锁页',
  full_report: '完整报告页', payment: '支付弹窗', unobserved: '具体页面未采集',
};
const runtimeReasons = {
  runtime_boot_html: '页面加载超过 20 秒，仍未收到 Flutter 启动配置',
  runtime_boot_timeout: 'Flutter 启动超过 90 秒，仍未显示首屏',
  runtime_boot_entry: 'Flutter 启动入口加载失败',
  runtime_boot_engine: 'Flutter 渲染引擎初始化失败',
  runtime_boot_app: 'Flutter 应用初始化失败',
  runtime_script_load: '浏览器没能加载 Flutter 启动脚本',
  runtime_js_type: '网页脚本使用了不符合预期的数据类型',
  runtime_js_reference: '网页脚本引用了无法访问的变量',
  runtime_js_syntax: '网页脚本遇到语法错误',
  runtime_js_range: '网页脚本使用了超出范围的值',
  runtime_rejection: '网页异步操作失败，程序未处理该异常',
  runtime_js_error: '网页脚本抛出异常，未采到具体类型',
  runtime_flutter_widgets: 'Flutter 页面组件处理出错',
  runtime_flutter_rendering: 'Flutter 页面布局或绘制出错',
  runtime_flutter_framework: 'Flutter 框架报告了异常，未采到具体环节',
};
const formProgress = {
  form_progress_empty: '尚无已确认的字段',
  form_progress_date: '未填完 · 需填写有效出生日期',
  form_progress_time: '未填完 · 还缺出生时间',
  form_progress_place: '未填完 · 还缺出生地',
  form_progress_complete: '资料已填完',
};
const visitActions = {
  ...formProgress,
  ...runtimeReasons,
  view: '打开页面', enter_form: '进入资料填写', edit_form: '修改资料', invalid_form: '提交资料未通过校验',
  select_birth_date: '打开出生日期选择', select_birth_time: '打开出生时间选择', select_birthplace: '打开出生地选择',
  consent_accept: '确认数据使用', consent_cancel: '取消数据使用确认', generate: '开始生成报告',
  generation_failed: '报告生成失败', retry_generation: '重试生成', cancel_generation: '返回 / 取消生成',
  report_ready: '报告内容已显示', report_failed: '报告加载失败', open_payment: '打开支付', close_payment: '关闭支付弹窗',
  create_order: '提交建单', order_created: '订单已创建', order_failed: '读取 / 创建订单失败', invalid_phone: '手机号校验未通过',
  open_cashier: '发起打开官方收银台', cashier_failed: '打开收银台失败', check_payment: '手动核对到账',
  payment_result: '支付界面收到成功结果', close_history: '关闭历史报告',
  leave_page: '离开当前页面', request_failed: '客户端请求失败',
  open_line_contact: '操作 LINE 领取入口', line_qr_shown: '显示 LINE 二维码',
  click_welcome_start: '点击欢迎页按钮', click_generate_report: '点击生成报告', click_line: '点击打开 LINE',
};
const visitStates = { visible: '上报时在前台', hidden: '已切到后台，去向未知', pagehide: '已离开页面（关闭 / 刷新 / 跳转）' };
const labels = {
  line_confirm: '确认 LINE 好友',
  line_retry: '重试生成 LINE 报告',
  line_mark_sent: '标记 LINE 报告已发送',
  tarot_receipt_lookup: '查询塔罗领取',
  tarot_receipt_accept: '标记塔罗已接单',
  tarot_receipt_mark_sent: '标记塔罗已发送',
  h5_code_lookup: '回查过期 App 登录码',
  ready: '生成完成',
  failed: '失败',
  stalled: '生成中断',
  queued: '已排队',
  generating: '生成中',
  preview: '预览就绪',
  pending: '待处理 / 未核验',
  paid: '到账已核验',
  check_failed: '查单失败',
  create_failed: '建单失败',
  needs_review: '结果待核查',
  simulated: '模拟订单',
  sandbox_paid: '沙箱已支付',
  seen: '已看预览',
  submitted: '已提交',
  visited: '已访问',
  succeeded: '操作成功',
  running: '执行中',
  live: '正式网关',
  sandbox: '沙箱 / 测试',
  simulation: '本地模拟',
  unavailable: '生成失败',
  unconfigured: '服务未配置',
  limited: '触发限额',
  not_started: '尚未开始',
  open: '待处理',
  untracked: '未跟进',
  investigating: '跟进中',
  resolved: '已处理',
  check_payment: '核对到账',
  retry_report: '重试报告',
  note: '记录跟进',
  payment: '支付异常',
  request: '接口失败',
  runtime: '前端程序错误',
  model: '模型尝试',
  report: '报告异常',
  life: '人生报告',
  fortune: '运势报告',
  zh: '中文',
  th: '泰语',
  full: '完整报告',
  chapter: '章节',
  plan: '行动计划',
  payment_verified: '到账核验通过',
  payment_pending: '本次核验尚未付清',
  historical_unknown: '历史未记录具体原因',
  client_network: '客户端网络失败或超时',
  client_badResult: '客户端无法解析响应',
  lease_expired: '生成租约已过期',
  'preview:unavailable': '预览生成失败',
  'preview:unconfigured': '预览服务未配置',
  'preview:limited': '预览请求限额',
  'full:unavailable': '完整报告生成失败',
  'full:unconfigured': '完整报告服务未配置',
  'full:limited': '完整报告请求限额',
  validation: '回执字段核验失败',
  http: '网关 HTTP 异常',
  parse: '回执解析异常',
  business: '网关业务异常',
  transport: '网络传输异常',
  association: '订单关联冲突',
};
const errors = {
  admin_permission_denied: '该账号没有访问此页面的权限。',
  admin_delivery_report_unavailable: '请先确认已加好友，并等待完整报告生成。',
  admin_delivery_not_pending: '这份报告不在待发送列表中。',
  admin_login_required: '登录已过期，请重新登录。',
  admin_not_configured: '尚未配置管理员，请在服务配置中设置管理员账号和密码哈希。',
  admin_invalid_credentials: '账号或密码不正确。',
  admin_login_limited: '尝试次数过多，请 15 分钟后重试。',
  admin_csrf_required: '会话校验已失效，请重新登录。',
  admin_origin_rejected: '请求来源校验失败，请从后台原地址访问。',
  admin_action_duplicate: '这次操作已经提交，请刷新详情查看操作记录。',
  admin_no_verifiable_order: '没有可以通过当前后台核验的正式网关订单，请查看订单回执。',
  admin_report_already_ready: '报告已经完成，无需重试。',
  admin_report_content_unavailable: '这个版本的正文尚未生成并保存。',
  admin_report_content_invalid: '这份报告的正文暂无法读取。',
  PDF_font_unavailable: 'PDF 字体加载失败，请刷新页面后重试。',
  PDF_runtime_unavailable: '报告组件加载失败，请刷新页面后重试。',
  PDF_engine_unavailable: 'PDF 生成组件加载失败，请刷新页面后重试。',
  PDF_invalid_output: 'PDF 文件生成失败，请稍后重试。',
  'Invalid report': '这份报告的正文暂无法读取。',
  admin_action_failed: '操作没有完成，请查看业务状态与操作记录。',
  life_payment_required: '该报告尚未获得解锁权限，请先核验到账。',
  life_order_needs_review: '建单结果不确定，请结合保存的回执人工核查，系统不会重复建单。',
  life_order_access_denied: '支付网关拒绝访问，请核查商户配置或权限。',
  life_order_channel_invalid: '支付渠道配置不正确，请核对网关接入配置。',
  life_order_rejected: '网关已拒绝该订单，请查看回执原因。',
  life_payment_verification_failed: '到账凭据未通过订单、金额或币种核验，请查看支付检查记录。',
  life_payment_unavailable: '当前支付配置不支持核验这笔订单。',
  life_report_generating: '这份报告仍在生成中，请稍后刷新。',
  admin_line_range_invalid: '请选择有效的起止时间，结束时间须晚于开始时间。',
  admin_expired_code_not_found: '未查到已过期且仍在 7 天保留期内的登录码。',
  admin_tarot_receipt_not_found: '未找到这个塔罗领取编号。',
  admin_tarot_receipt_not_accepted: '请先接单，再登记已发送。',
  admin_retry_limited: '生成请求触发限额，请稍后再试。',
  life_report_not_found: '这份报告已不存在。',
  too_many_requests: '刷新过于频繁，请稍后再试。',
  admin_visit_range_invalid: '请选择有效的开始和结束日期。',
  request_failed: '请求失败，请稍后重试。',
};
const verifiedOrdersRoute = 'orders?time_basis=verified';
const lineSentRoute = 'line-contacts?delivery=sent';
const firstReportsRoute = 'reports?report_scope=first';
const lineSentTitle = '已登记发送';
const visitFunnelStartDate = '2026-11-20';
const reportEditionNames = { preview: '免费报告', full: '完整报告' };
const loadReportRuntime = () => import('/thai-landing/runtime/report-pdf.js').catch(() => {
  throw new Error('PDF_runtime_unavailable');
});
const lineDeliveryTabs = { pending: '待发报告', unconfirmed: '待确认好友', sent: '已发送' };
const state = {
  session: null,
  view: 'overview',
  timeBasis: 'created',
  firstReportsOnly: false,
  days: 30,
  page: 1,
  q: '',
  status: '',
  source: '',
  category: '',
  caseStatus: '',
  lineDelivery: 'pending',
  lineRange: { preset: 'today' },
  visitRange: null,
  funnelMeasure: 'people',
  funnelMetrics: null,
  overview: null,
  overviewDays: null,
  records: null,
  detail: null,
  action: null,
  requestId: null,
  revision: 0,
};
const label = (value) => labels[value] || value || '—';
function errorReason(row) {
  if (row.category === 'runtime') return runtimeReasons[row.code] || '未采到具体原因';
  if (row.code === 'server_TimeoutError') return '服务端处理请求超时';
  if (row.code?.startsWith('server_')) return '服务端抛出 ' + row.code.slice(7) + ' 异常';
  if (row.category === 'model') {
    const reasons = {ReadTimeout: '等待模型返回内容超时', ConnectTimeout: '连接模型服务超时',
      ConnectError: '无法连接模型服务', TimeoutError: '模型调用超时', protocol: '模型返回的数据格式异常',
      evidence_invalid: '报告内容未通过依据校验', validation_failed: '模型输出未通过校验'};
    if (reasons[row.code]) return reasons[row.code];
  }
  return errors[row.code] || labels[row.code] || row.description ||
    (row.category === 'model' ? '模型调用未通过，详见错误码' : '未记录更具体的原因');
}
function issueLocation(row) {
  if (row.category === 'runtime') return visitPages[row.path] || row.path;
  if (row.category === 'model') return '单次模型调用';
  return row.path;
}
const badge = (value) => {
  const type = ['ready', 'paid', 'succeeded', 'resolved'].includes(value)
    ? 'success'
    : ['failed', 'stalled', 'create_failed', 'check_failed', 'unavailable'].includes(value)
      ? 'danger'
      : ['needs_review', 'pending', 'queued', 'limited', 'unconfigured', 'running', 'investigating'].includes(
            value,
          )
        ? 'warning'
        : ['preview', 'generating', 'seen', 'sandbox_paid'].includes(value)
          ? 'info'
          : '';
  return `<span class="badge ${type}">${esc(label(value))}</span>`;
};
const sourceName = (row) =>
  row.source || (row.attribution === 'unattributed' ? '未归因' : '未标记');
const empty = (text) =>
  `<div class="empty">${icon('sources')}<strong>${esc(text)}</strong><small>可以调整时间范围或清空筛选后再查看。</small></div>`;

async function api(path, { method = 'GET', body } = {}) {
  const session = state.session;
  let response;
  try {
    response = await fetch('/api/admin' + path, {
      method,
      credentials: 'same-origin',
      cache: 'no-store',
      signal: AbortSignal.timeout(method === 'GET' ? 20000 : 60000),
      headers: {
        'Accept-Language': 'zh',
        'Content-Type': 'application/json',
        'X-Admin-Request': '1',
        ...(session ? { 'X-CSRF-Token': session.csrf } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
  } catch {
    throw Error('连接服务超时或中断，请检查服务后重试。业务操作可先刷新详情核查结果。');
  }
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (response.status === 401 && path !== '/login' && state.session === session) showLogin();
    throw Error(errors[data.code] || label(data.code) || `请求未完成（${response.status}）`);
  }
  return data;
}
function toast(message) {
  $('#toast').textContent = message;
  $('#toast').hidden = false;
  clearTimeout(state.toastTimer);
  state.toastTimer = setTimeout(() => ($('#toast').hidden = true), 4500);
}
function showLogin() {
  state.revision++;
  state.session = null;
  state.overview = null;
  state.overviewDays = null;
  state.records = null;
  state.detail = null;
  state.detailRequest = null;
  state.lineRange = { preset: 'today' };
  state.visitRange = null;
  state.funnelMetrics = null;
  $('#content').replaceChildren();
  $('#detail-content').replaceChildren();
  $('#detail-dialog').close();
  $('#action-dialog').close();
  $('#workspace').hidden = true;
  $('#login-view').hidden = false;
}
function navigate(view, { refresh = false } = {}) {
  state.timeBasis = view === verifiedOrdersRoute ? 'verified' : 'created';
  if (state.timeBasis === 'verified') view = 'orders';
  const showSent = view === lineSentRoute;
  const firstReportsOnly = view === firstReportsRoute;
  if (showSent) view = 'line-contacts';
  if (firstReportsOnly) view = 'reports';
  if (!views[view]) view = 'overview';
  if (state.session?.role === 'report_support') view = 'line-contacts';
  state.view = view;
  state.firstReportsOnly = view === 'reports' && firstReportsOnly;
  state.page = 1;
  state.q = '';
  state.status = '';
  state.source = '';
  state.category = '';
  state.caseStatus = '';
  state.lineDelivery = showSent ? 'sent' : 'pending';
  return loadView({ refresh });
}
function nav() {
  const visible = state.session.role === 'report_support' ? ['line-contacts'] : Object.keys(views);
  $('#navigation').innerHTML = visible
    .map(
      (key) =>
        `${key === 'audit' ? '<div class="nav-divider"></div>' : ''}<a href="#${key}" class="nav-item ${state.view === key ? 'active' : ''}" title="${views[key][0]}" ${state.view === key ? 'aria-current="page"' : ''}>${icon(key)}<span class="nav-text">${views[key][0]}</span>${key === 'issues' && state.overview ? `<span class="nav-count">${number(state.overview.metrics.report_failures + state.overview.metrics.order_issues)}</span>` : ''}</a>`,
    )
    .join('');
}
async function openWorkspace() {
  $('#login-view').hidden = true;
  $('#workspace').hidden = false;
  $('#actor-name').textContent = state.session.username;
  $('#database-name').textContent = '';
  $('#environment').textContent = state.session.role === 'report_support' ? '客服账号' : '连接中';
  await navigate(location.hash.slice(1), { refresh: true });
}
function showPageError(error) {
  $('#page-error').textContent = error.message;
  $('#page-error').hidden = false;
}
const beijingDay = () => new Date(Date.now() + 8 * 3_600_000);
function lineRangeValues() {
  if (!state.lineRange.preset) return state.lineRange;
  const day = beijingDay();
  const today = day.toISOString().slice(0, 10);
  day.setUTCDate(day.getUTCDate() + 1);
  const tomorrow = day.toISOString().slice(0, 10);
  return {
    start: today + 'T00:00',
    end: state.lineRange.preset === 'morning' ? today + 'T12:00' : tomorrow + 'T00:00',
  };
}
const lineEpoch = (value) => Date.parse(value + '+08:00') / 1000;
function renderLineCounts(reportCounts, visitorCounts) {
  $('#line-report-counts').querySelectorAll('[data-line-count]').forEach((element) => {
    const deduplicated = element.hasAttribute('data-line-dedup');
    const count = (deduplicated ? visitorCounts : reportCounts)?.[element.dataset.lineCount];
    element.textContent = count == null ? '—' : `${number(count)} ${deduplicated ? '人' : '份'}`;
  });
}
async function loadView({ refresh = false } = {}) {
  if (!state.session) return;
  const revision = ++state.revision,
    view = state.view,
    days = state.days;
  nav();
  const [title, description] = state.firstReportsOnly
    ? ['报告创建去重明细', '每位浏览器访客只显示首份报告，按首次创建时间筛选。']
    : views[view];
  $('#page-title').textContent = title;
  $('#breadcrumb-title').textContent = title;
  $('#page-description').textContent = description;
  const isVisitFunnel = view === 'visit-funnel';
  $('#visit-funnel-controls').hidden = !isVisitFunnel;
  $('#days').hidden = isVisitFunnel;
  let visitRange;
  if (isVisitFunnel) {
    const today = beijingDay().toISOString().slice(0, 10);
    visitRange = state.visitRange ?? {
      start_date: today < visitFunnelStartDate ? today : visitFunnelStartDate,
      end_date: today,
    };
    const from = $('#visit-range-start');
    const through = $('#visit-range-end');
    from.max = through.max = today;
    from.value = visitRange.start_date;
    through.value = visitRange.end_date;
    $('#visit-applied-range').textContent = `${visitRange.start_date} 至 ${visitRange.end_date}（北京时间）`;
    $('#visit-range-error').hidden = true;
    state.funnelMetrics = null;
  }
  const lineRange = view === 'line-contacts' ? lineRangeValues() : null;
  $('#line-stats').hidden = !lineRange;
  if (lineRange) {
    $('#line-range-start').value = lineRange.start;
    $('#line-range-end').value = lineRange.end;
    $('#line-range-error').hidden = true;
    $('#line-applied-range').textContent =
      `${lineRange.start.replace('T', ' ')} 至 ${lineRange.end.replace('T', ' ')}（结束时间不计入）`;
    document.querySelectorAll('[data-line-range]').forEach((button) => {
      button.setAttribute('aria-pressed', String(button.dataset.lineRange === state.lineRange.preset));
    });
    renderLineCounts(null);
  }
  $('#page-error').hidden = true;
  $('#content').innerHTML = '<div class="loading">正在读取业务数据…</div>';
  try {
    if (state.session.role === 'admin' && (view === 'overview' || refresh || state.overviewDays !== days)) {
      const overview = await api(`/overview?days=${days}`);
      if (revision !== state.revision || !state.session) return;
      state.overview = overview;
      state.overviewDays = days;
      $('#database-name').textContent = overview.database;
      $('#environment').textContent =
        overview.environment === 'production' ? '生产环境' : '本地开发环境';
      nav();
    }
    let data;
    if (view === 'overview') {
      const params = new URLSearchParams({ days, page_size: 5 });
      data = await api('/records/reports?' + params);
    } else if (visitRange) data = await api('/visit-funnel?' + new URLSearchParams(visitRange));
    else if (['ad-funnel', 'page-diagnostics', 'tarot-activity'].includes(view)) data = await api(`/${view}?days=${days}`);
    else if (view === 'sources') data = await api('/sources');
    else if (view === 'line-contacts') {
      const params = new URLSearchParams({
        days, page: state.page, report_id: state.q, delivery: state.lineDelivery,
        contact_start: lineEpoch(lineRange.start), contact_end: lineEpoch(lineRange.end),
      });
      data = await api('/line-contacts?' + params);
    }
    else
      data = await api(
        `/records/${view}?` +
          new URLSearchParams({
            days,
            page: state.page,
            q: state.q,
            status: state.status,
            source: state.source,
            category: state.category,
            case_status: state.caseStatus,
            time_basis: state.timeBasis,
            report_scope: state.firstReportsOnly ? 'first' : 'all',
          }),
      );
    if (revision !== state.revision || !state.session) return;
    if (view === 'overview') renderOverview(data.items);
    else if (view === 'visit-funnel') {
      state.funnelMetrics = data;
      renderVisitFunnel(data);
    }
    else if (view === 'ad-funnel') renderAdFunnel(data);
    else if (view === 'page-diagnostics') renderPageDiagnostics(data);
    else if (view === 'tarot-activity') renderTarotActivity(data);
    else if (view === 'sources') renderSources(data.items);
    else if (view === 'line-contacts') {
      if (state.page > data.last_page) {
        state.page = data.last_page;
        if (data.total > 0) return loadView();
      }
      renderLineCounts(data.report_counts, data.first_contact_visitor_counts);
      renderLineContacts(data);
    }
    else {
      state.records = data;
      renderRecords(data);
    }
    $('#updated-at').textContent = `更新于 ${fullDate(Date.now() / 1000)}`;
  } catch (error) {
    if (revision === state.revision) {
      $('#content').innerHTML = empty('数据暂时无法读取');
      showPageError(error);
    }
  }
}

function renderLineContacts(data) {
  const occurred = data.activity_by_occurrence;
  const generation = {
    ready: '已生成', not_started: '未开始',
    queued: '等待生成', pending: '等待生成', generating: '正在生成',
    limited: '生成额度已满', unavailable: '生成失败', unconfigured: '生成服务未配置',
  };
  const rows = data.items.map((row) => {
    const confirmed = row.line_confirmed_at != null;
    const sent = row.line_sent_at != null;
    const ready = confirmed && row.full_state === 'ready';
    const status = sent ? '已发送' : !confirmed ? '待确认好友'
      : ready ? '待发送' : generation[row.full_state] || '待生成';
    const action = (name, title) =>
      `<button type="button" class="button" data-line-action="${name}" data-line-report="${esc(row.id)}">${title}</button>`;
    const canRetry = confirmed && !sent && !ready && !['queued', 'pending', 'generating'].includes(row.full_state);
    return `<tr>${[
      `<span class="mono">${esc(row.claim_code)}</span>`,
      fullDate(row.line_contact_at),
      fullDate(row.line_confirmed_at),
      `<strong>${status}</strong>${sent ? `<small>${fullDate(row.line_sent_at)}</small>` : ''}`,
      `<div class="line-actions">
        ${!confirmed ? action('confirm', '确认已加好友') : ''}
        ${canRetry ? action('retry', '重试生成') : ''}
        ${ready ? action('download', '下载 PDF') : ''}
        ${ready && !sent ? action('mark_sent', '标记已发送') : ''}
      </div>`,
    ].map((cell) => `<td>${cell}</td>`).join('')}</tr>`;
  });
  $('#content').innerHTML = `<div class="line-metrics">
    <section class="stat-card">
      <div class="stat-top"><h3>二维码展示次数</h3></div>
      <div class="stat-value">${number(data.metrics.qr_popups)}<span class="unit">次</span></div>
      <p class="stat-hint">按收到时间计次。${occurred ? `其中在所选时段发生 ${number(occurred.qr_popups)} 次。` : ''}</p>
    </section>
    <section class="stat-card">
      <div class="stat-top"><h3>领取入口操作人数</h3></div>
      <div class="stat-value">${number(data.metrics.click_visitors)}<span class="unit">人</span></div>
      <p class="stat-hint">按收到时间去重。${occurred ? `其中在所选时段操作 ${number(occurred.click_visitors)} 人。` : ''}</p>
    </section>
  </div>
  <section class="panel line-stats" aria-labelledby="line-code-lookup-title">
    <div class="data-group-heading"><h2 id="line-code-lookup-title">回查过期 App 登录码</h2></div>
    <p class="stat-hint">可查签发后 7 天内已过期的 6 位码。</p>
    <form class="filters" id="line-code-lookup">
      <div class="search"><input aria-label="过期 App 登录码" placeholder="粘贴 6 位登录码"
        autocomplete="off" spellcheck="false" maxlength="6" pattern="[A-Za-z0-9]{6}" required></div>
      <button class="button" type="submit">查用户和报告</button>
    </form>
    <div id="line-code-result" role="status"></div>
  </section>
  <section class="panel line-stats" aria-labelledby="tarot-lookup-title">
    <div class="data-group-heading"><h2 id="tarot-lookup-title">塔罗领取编号查询</h2></div>
    <p class="stat-hint">收到 LINE 咨询后，用领取码查询原问题和牌阵。</p>
    <form class="filters" id="tarot-receipt-lookup">
      <div class="search"><input aria-label="塔罗领取编号" placeholder="例如 T12345"
        autocomplete="off" spellcheck="false" maxlength="20" required></div>
      <button class="button" type="submit">查询并生成解读</button>
    </form>
    <div id="tarot-receipt-result"></div>
    <p id="tarot-receipt-status" class="stat-hint" role="status"></p>
  </section>
  <p class="data-note">「时间范围」筛选上方两项数据，最多保留 30 天。二维码展示按图片进入报告视口计次。点击打开 LINE 或在电脑复制领取编号，均算领取入口操作，同一浏览器计一人。下方待办和编号查询可跨日期。</p>
  <section class="panel table-panel">
    <div class="line-delivery-tabs" role="group" aria-label="报告发放分类">
      ${Object.entries(lineDeliveryTabs).map(([key, title]) =>
        `<button type="button" class="button" data-line-tab="${key}" aria-pressed="${!state.q && state.lineDelivery === key}">${title}</button>`
      ).join('')}
    </div>
    <form class="filters" id="line-search">
      <div class="search"><span aria-hidden="true">⌕</span><input id="line-report-id" aria-label="领取编号" placeholder="粘贴领取编号" maxlength="128" value="${esc(state.q)}"></div>
      <button class="button" type="submit">查询</button>
    </form>
    <div class="summary-line"><span>共 <strong>${number(data.total)}</strong> 份</span></div>
    ${rows.length ? table(['领取编号', '首次领取记录', '确认加好友', '发送状态', '操作'], rows)
      : `<div class="empty">${icon('reports')}<strong>${state.q ? '未找到此编号的预览报告' : '此分类暂无报告'}</strong></div>`}
    <div class="table-footer"><span>第 ${state.page} 页</span><div class="pagination">
      <button type="button" class="button" id="line-prev" ${state.page <= 1 ? 'disabled' : ''}>上一页</button>
      <button type="button" class="button" id="line-next" ${data.has_more ? '' : 'disabled'}>下一页</button>
    </div></div></section>`;
  bindTarotReceiptLookup();
  const lookupForm = $('#line-code-lookup');
  const lookupInput = lookupForm.querySelector('input');
  const lookupButton = lookupForm.querySelector('button');
  const lookupResult = $('#line-code-result');
  lookupForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (lookupButton.disabled || !lookupForm.reportValidity()) return;
    const code = lookupInput.value;
    lookupInput.value = '';
    lookupButton.disabled = true;
    lookupResult.textContent = '正在查询…';
    try {
      const result = await api('/line-contacts/app-code-lookup', { method: 'POST', body: { code } });
      if (lookupInput.value) return;
      const latest = result.latest_report;
      const rows = [
        ['App 用户编号', result.user_id || '尚未绑定 App'],
        ['H5 访客编号', result.visitor_number ?? '未记录'],
        ['发码时的报告领取编号', result.issued_claim_code ?? '未记录'],
      ];
      if (latest) rows.push(
        ['最新报告领取编号', latest.claim_code],
        ['创建时间', fullDate(latest.created)],
        ['预览', generation[latest.preview_state] || label(latest.preview_state)],
        ['完整版', generation[latest.full_state] || label(latest.full_state)],
      );
      lookupResult.innerHTML = `<dl class="detail-fields">${rows.map(([title, value]) =>
        `<div><dt class="field-label">${title}</dt><dd class="field-value mono">${esc(value)}</dd></div>`).join('')}</dl>
        ${latest ? '' : '<p>这个用户目前没有报告。</p>'}`;
    } catch (error) {
      if (!lookupInput.value) lookupResult.textContent = error.message;
    } finally {
      lookupButton.disabled = false;
    }
  });
  $('#line-search').addEventListener('submit', (event) => {
    event.preventDefault();
    const input = $('#line-report-id');
    const query = input.value.trim();
    if (/^[A-Za-z0-9]{6}$/.test(query)) {
      input.value = state.q;
      lookupInput.value = query.toUpperCase();
      lookupResult.textContent = '已移到「回查过期 App 登录码」，请点击「查用户和报告」。';
      lookupInput.focus();
      return;
    }
    state.q = query;
    state.page = 1;
    loadView();
  });
  $('#line-prev').addEventListener('click', () => { state.page--; loadView(); });
  $('#line-next').addEventListener('click', () => { state.page++; loadView(); });
  $('#content').querySelectorAll('[data-line-tab]').forEach((button) => {
    button.addEventListener('click', () => {
      state.lineDelivery = button.dataset.lineTab;
      state.q = '';
      state.page = 1;
      loadView();
    });
  });
  $('#content').querySelectorAll('[data-line-action]').forEach((button) => {
    button.addEventListener('click', async () => {
      const session = state.session;
      const action = button.dataset.lineAction;
      const path = `/line-contacts/${encodeURIComponent(button.dataset.lineReport)}`;
      const label = button.textContent;
      button.disabled = true;
      try {
        if (action === 'download') {
          button.textContent = '正在准备 PDF…';
          const { exportDocument } = await loadReportRuntime();
          if (state.session !== session) return;
          const report = await api(path + '/report', { method: 'POST' });
          if (state.session !== session) return;
          const result = await exportDocument(JSON.stringify(report), 'pdf', { showSaveDialog: false });
          if (state.session === session && result !== 'cancelled') toast('PDF 下载已开始，请在浏览器下载列表中查看。');
        } else {
          const result = await api(path + '/actions', { method: 'POST', body: { action } });
          if (state.session !== session) return;
          toast(action === 'mark_sent' ? '已标记发送'
            : result.full_state === 'ready' ? '报告可下载'
            : result.full_state === 'limited' ? '生成额度已满，可稍后重试'
            : '已提交生成，稍后刷新查看。');
          if (state.view === 'line-contacts') await loadView();
        }
      } catch (error) {
        toast(errors[error.message] || error.message);
      } finally {
        button.textContent = label;
        button.disabled = false;
      }
    });
  });
}
function bindTarotReceiptLookup() {
  const form = $('#tarot-receipt-lookup');
  const input = form.querySelector('input');
  const lookupButton = form.querySelector('button');
  const output = $('#tarot-receipt-result');
  const status = $('#tarot-receipt-status');
  let current = null;

  function renderReceipt(receipt) {
    const spread = window.TarotCore?.spreads?.[receipt.spread_id];
    const catalog = window.TAROT_CONTENT?.cards || [];
    const cards = receipt.cards.map((card, index) => {
      const name = catalog.find((entry) => entry.id === card.id)?.name.zh || `牌号 ${card.id}`;
      const position = spread?.positions[index]?.zh || `牌位 ${index + 1}`;
      return `<li>${esc(position)} · ${esc(name)} · ${card.reversed ? '逆位' : '正位'}</li>`;
    }).join('');
    const deliveryStatus = receipt.sent_at != null ? '已发送' : receipt.accepted_at != null ? '待发送' : '待接单';
    const fields = [
      ['领取编号', receipt.claim_code],
      ['报告参考编号', receipt.report_id],
      ['报告语言', receipt.language === 'th' ? '泰文' : '简体中文'],
      ['牌阵', spread?.name.zh || receipt.spread_id],
      ['发放状态', deliveryStatus],
      ['登记时间', fullDate(receipt.created_at)],
      ['接单时间', fullDate(receipt.accepted_at)],
      ['发送时间', fullDate(receipt.sent_at)],
    ];
    const nextAction = receipt.accepted_at == null ? ['accept', '标记接单'] : ['mark_sent', '标记已手工发送'];
    output.innerHTML = `<dl class="detail-fields">${fields.map(([name, value]) =>
      `<div><dt class="field-label">${name}</dt><dd class="field-value">${esc(value)}</dd></div>`
    ).join('')}</dl>
      <p class="field-value"><strong>咨询问题</strong><br>${esc(receipt.question)}</p>
      <ol>${cards}</ol>
      <label for="tarot-copy-text">完整塔罗解读</label>
      <textarea id="tarot-copy-text" rows="12" readonly spellcheck="false"></textarea>
      <div class="line-actions">
        <button class="button" type="button" data-copy-tarot>复制完整解读</button>
        ${receipt.sent_at == null ? `<button class="button" type="button" data-tarot-action="${nextAction[0]}">${nextAction[1]}</button>` : ''}
      </div>`;
    const report = {
      id: receipt.report_id, claimCode: receipt.claim_code, question: receipt.question,
      topic: receipt.topic, spreadId: receipt.spread_id, cards: receipt.cards,
    };
    output.querySelector('textarea').value = window.TarotReading.formatText(report, receipt.language, true);
  }

  input.addEventListener('input', () => {
    current = null;
    output.replaceChildren();
    status.textContent = '';
  });
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (lookupButton.disabled) return;
    const code = input.value.trim().toUpperCase();
    input.value = code;
    if (!/^(?:T[1-9][0-9]{4}|T-(?:[0-9A-HJKMNP-TV-Z]{12}|[1-9][0-9]{5,17}))$/.test(code)) {
      status.textContent = '请输入完整的塔罗领取编号。';
      return;
    }
    lookupButton.disabled = true;
    current = null;
    output.replaceChildren();
    const session = state.session;
    status.textContent = '正在查询并生成解读…';
    try {
      const result = await api('/line-contacts/tarot-lookup', { method: 'POST', body: { code } });
      await Promise.all([
        import('/tarot/content.js'), import('/tarot/core.js'), import('/tarot/reading.js?v=23.16'),
      ]);
      if (!form.isConnected || input.value !== code || state.session !== session) return;
      current = result;
      renderReceipt(current);
      status.textContent = '';
    } catch (error) {
      if (form.isConnected && input.value === code) status.textContent = error.message;
    } finally {
      lookupButton.disabled = false;
    }
  });
  output.addEventListener('click', async (event) => {
    if (event.target.closest('[data-copy-tarot]')) {
      const field = output.querySelector('textarea');
      try {
        await navigator.clipboard.writeText(field.value);
        if (field.isConnected) status.textContent = '已复制，可以发给用户。';
      } catch {
        field.focus();
        field.select();
        if (field.isConnected) status.textContent = '请手动复制已选中的解读。';
      }
      return;
    }
    const button = event.target.closest('[data-tarot-action]');
    const receipt = current;
    if (!button || button.disabled || !receipt) return;
    const action = button.dataset.tarotAction;
    button.disabled = true;
    status.textContent = '';
    try {
      const updates = await api('/line-contacts/tarot-status', {
        method: 'POST', body: { code: receipt.claim_code, action },
      });
      if (!form.isConnected || current !== receipt) return;
      current = { ...receipt, ...updates };
      renderReceipt(current);
      status.textContent = action === 'accept' ? '已标记接单。' : '已登记手工发送。';
    } catch (error) {
      if (form.isConnected && current === receipt) status.textContent = error.message;
    } finally {
      button.disabled = false;
    }
  });
}

const reportLink = (row) =>
  row.action?.startsWith('tarot_receipt_')
    ? `<span class="mono">${esc(row.report_id || '未关联')}</span>`
    : row.report_id === null
    ? '<span class="muted">报告尚未创建 / 无关联</span>'
    : row.report_exists === false
      ? `<span class="muted" title="${esc(row.report_id)}">报告已删除</span>`
      : `<button class="link mono row-detail" data-report="${esc(row.report_id || row.id)}" title="${esc(row.report_id || row.id)}">${esc(short(row.report_id || row.id))} ↗</button>`;
const visitorId = (row) =>
  row.visitor_number ? `<small class="mono">${esc(row.visitor_number)}</small>` : '';
const sourceCell = (row) => {
  const region = 'entry_region' in row ? row.entry_region : row.region_code;
  return `<strong>${esc(sourceName(row))}</strong><small>${esc(row.campaign || '无活动标签')}${region ? ' · ' + esc(region) : ''}</small>`;
};
const table = (headers, rows, compact = false) =>
  `<div class="table-wrap"><table class="${compact ? 'compact' : ''}"><thead><tr>${headers.map((value) => `<th scope="col">${value}</th>`).join('')}</tr></thead><tbody>${rows.join('')}</tbody></table></div>`;
function reportTable(rows) {
  return rows.length
    ? table(
        ['报告 / 访客', '首次来源', '生成状态', '解锁权限', '创建时间', '处理进度'],
        rows.map(
          (row) =>
            `<tr><td>${reportLink(row)}${visitorId(row)}<small>${esc(row.name || '匿名访客')} · ${esc(label(row.language))}</small></td><td>${sourceCell(row)}</td><td>${badge(row.status)}</td><td>${badge(
              row.unlocked ? 'resolved' : 'pending',
            )
              .replace('已处理', '已解锁')
              .replace(
                '待处理 / 未核验',
                '未解锁',
              )}</td><td>${date(row.created)}</td><td>${badge(row.case_status)}<small><button class="link" data-report="${esc(row.id)}">详情 →</button></small></td></tr>`,
        ),
      )
    : empty('当前范围没有报告');
}
function renderPageDiagnostics(data) {
  const pageRows = data.pages.map(row => `<tr><td>${esc(visitPages[row.page] || row.page)}</td><td>${number(row.entries)}</td><td>${duration(row.average_ms)}</td><td>${duration(row.visible_ms)}</td></tr>`);
  const errorRows = data.errors.map(row => `<tr><td>${date(row.created)}</td><td>${esc(label(row.category))}<small>${esc(issueLocation(row))}${row.http_status ? ' · HTTP ' + number(row.http_status) : ''}</small></td>
    <td>${esc(errorReason(row))}<small class="mono">${esc(row.code)}</small></td><td>${visitorId(row)}${visitLink(row.visit_id)}${row.report_id ? reportLink(row) : ''}${!row.visit_id && !row.report_id ? '未关联' : ''}</td></tr>`);
  $('#content').innerHTML = `<section class="panel table-panel"><div class="panel-header"><div><h3>各页面停留时间</h3><p class="muted">按访问开始时间筛选。平均每次停留按有记录的页面打开次数计算，只累计前台可见时间。</p></div><a href="#visits">逐次访问 ↗</a></div>
    ${pageRows.length ? table(['页面', '有记录的打开次数', '平均每次停留', '累计前台停留'], pageRows) : empty('这段时间没有采到页面停留记录')}</section>
    <section class="panel table-panel"><div class="panel-header"><div><h3>最近的程序错误</h3><p class="muted">按记录时间展示最近 25 条。同次打开页面的同类前端异常只记首次；模型失败按单次调用记录。</p></div><a href="#issues">全部异常 ↗</a></div>
    ${errorRows.length ? table(['北京时间', '出错环节', '记录到的原因', '关联访问或报告'], errorRows) : empty('这段时间没有记录到程序错误')}</section>
    <p class="data-note">最多显示最近 30 天。浏览器关闭前未送达的记录可能缺失。<a href="#sources">查看统计口径 ↗</a></p>`;
}
function renderTarotActivity(data) {
  const pages = {
    home: '塔罗首页 / 首次提问', draw: '选牌页', reflection: '选牌后填写问题',
    report_loading: '报告加载页', report: '基础报告页', archive: '我的塔罗报告',
    line_receipt: 'LINE 领取弹窗', chat: '塔罗对话页',
  };
  const actions = {
    reading_start: '点击开始抽牌', draw_first_started: '开始先抽牌流程', draw_first_resumed: '继续先抽牌流程',
    card_selected: '选中一张牌', draw_first_question_confirmed: '选牌后确认问题', draw_resumed: '恢复已有选牌',
    question_confirmed: '首次确认问题', spread_matched: '匹配牌阵', clarification_shown: '展示追问',
    question_clarified: '确认追问', spread_changed: '更换牌阵', spread_confirmed: '确认牌阵',
    free_report_generated: '生成基础报告', line_message_copied: '成功复制领取码', line_open_clicked: '点击打开 LINE',
    report_export: '导出报告', app_handoff: '点击进入塔罗对话', companion_message: '发送对话消息',
    plan_checked: '切换行动项勾选', suggestion_refresh: '更换问题建议',
    consultation_example_selected: '选择示例问题', consultation_cta: '点击使用示例问题',
  };
  $('#content').innerHTML = `
    <section class="panel table-panel" aria-label="塔罗页面访问">
      <div class="panel-header"><h3>塔罗页面访问</h3></div>
      ${table(['页面', '进入人数（去重）', '进入次数', '总可见停留', '平均每次停留'], data.pages.map(row =>
        `<tr><th scope="row">${esc(pages[row.event])}</th><td>${number(row.people)}</td><td>${number(row.times)}</td>
        <td>${duration(row.total_ms)}</td><td>${duration(row.average_ms)}</td></tr>`), true)}
    </section>
    <p class="data-note">每页人数按匿名浏览器去重，重复进入照常计次。只累计页面可见时间，切到后台暂停计时。按服务器首次收到记录的时间筛选，从启用埋点后开始统计。</p>
    <section class="panel table-panel" aria-label="塔罗操作统计">
      <div class="panel-header"><h3>塔罗操作统计</h3></div>
      ${table(['操作', '操作人数（去重）', '操作次数'], data.actions.map(row =>
        `<tr><th scope="row">${esc(actions[row.event])}</th><td>${number(row.people)}</td><td>${number(row.times)}</td></tr>`), true)}
    </section>
    <p class="data-note">同一浏览器重复操作照常计次。点击打开 LINE 统计的是站内点击。</p>`;
}
function renderVisitFunnel(metrics) {
  const measure = state.funnelMeasure;
  const steps = [
    ['进入资料填写页', { people: metrics.birth_form_people, visits: metrics.birth_form_visits, events: metrics.birth_form_views }, '次打开'],
    ['点击生成报告', { people: metrics.generate_click_people, visits: metrics.generate_click_visits, events: metrics.generate_clicks }, '次点击'],
    ['点击 LINE 按钮', { people: metrics.line_click_people, visits: metrics.line_click_visits, events: metrics.line_clicks }, '次点击'],
  ];
  $('#content').innerHTML = `
    <section class="panel" aria-label="H5 访问步骤"><div class="panel-body">
      <dl class="visit-funnel">${steps.map(([name, counts, eventUnit]) => `
        <div class="visit-funnel-step">
          <dt>${name}</dt>
          <dd><strong>${number(counts[measure])}</strong> ${{ people: '人', visits: '人次', events: eventUnit }[measure]}</dd>
        </div>`).join('')}</dl>
    </div></section>
    <p class="data-note">按北京时间的访问开始日期筛选，包含起止当天。人数按浏览器去重，人次按访问去重，次数按打开或点击累计。访问记录保留最近 30 天。<a href="#sources">统计口径 ↗</a></p>`;
}
function renderAdFunnel(metrics) {
  const steps = [
    ['广告进入 H5', metrics.entry_people, `页面访问 ${number(metrics.entry_visits)} 次<small>广告链接点击数：未接入</small>`],
    ['到达个人信息填写页', metrics.birth_form_people, '打开填写页即计入'],
    ['点击生成报告', metrics.generate_click_people, '从新版启用后记录，含校验未通过的点击'],
    ['点击 LINE', metrics.line_click_people, '从新版启用后记录打开 LINE 的按钮点击'],
  ];
  $('#content').innerHTML =
    `<p class="data-note">统计同时带有来源和活动标签的 H5 访问，包括历史欢迎页访问和直接打开填写页。按访问开始时间筛选，最多查看最近 30 天。同一步每个浏览器计一次。<a href="#sources">统计口径 ↗</a></p>
    ${metrics.welcome_visits ? `<p class="data-note">历史欢迎页记录 ${number(metrics.welcome_people)} 人访问，${number(metrics.welcome_click_people)} 人点击欢迎页按钮。</p>` : ''}
    <section class="panel table-panel" aria-label="广告转化步骤">${table(
      ['步骤', '已记录人数', '说明'],
      steps.map(([name, people, detail]) =>
        `<tr><td><strong>${name}</strong></td><td>${number(people)} 人</td><td>${detail}</td></tr>`),
      true,
    )}</section>`;
}
function renderOverview(reports) {
  const { metrics: m, channels, trend } = state.overview;
  const cards = [
    [
      'visits', '访问人数', number(m.visitors), '人',
      '范围内每个浏览器计一次', `访问次数 ${number(m.visits)} 次`, 'visits',
    ],
    [
      'visits', '次日回访人数', m.next_day_return_visitors == null ? null : number(m.next_day_return_visitors), '人',
      '连续两天有访问记录的浏览器', '按回访日期筛选，范围内去重',
    ],
    [
      'reports', '报告创建量', number(m.reports), '份',
      '按报告创建日期统计', `已解锁 ${number(m.unlocked)} 份`, 'reports',
    ],
    [
      'visits', '报告创建（去重）', m.first_report_creators == null ? null : number(m.first_report_creators), '人',
      '按首次创建报告的时间统计', '同一浏览器访客只计一次', firstReportsRoute,
    ],
    [
      'reports', lineSentTitle, number(m.line_sent), '份',
      '按发送登记时间筛选，每份报告计一次', '查看 LINE 发放明细', lineSentRoute,
    ],
    [
      'orders', '核验实收', money(m.revenue), '泰铢',
      '按服务端核验通过时间统计正式到账', `已到账订单 ${number(m.paid)} 笔`, verifiedOrdersRoute,
    ],
    [
      'issues', '当前异常报告', number(m.report_failures), '份',
      '范围内当前失败或中断的报告', `待核查订单 ${number(m.order_issues)} 笔`, 'issues',
    ],
  ];
  const max = Math.max(1, ...trend.map((row) => row.reports));
  const chart = trend.length
    ? `<div class="bar-chart" role="img" aria-label="最近 30 天报告创建量和当前异常报告数">${trend.map((row) => `<div class="chart-day" title="${esc(row.day)}：${row.reports} 份报告，${row.failed} 份当前异常"><div class="chart-bar" style="height:${(row.reports / max) * 92}%"></div><div class="chart-bar failed" style="height:${(row.failed / max) * 92}%"></div></div>`).join('')}</div><div class="chart-labels"><span>${esc(trend[0].day)}</span><span>${esc(trend.at(-1).day)}</span></div>`
    : empty('暂无趋势数据');
  $('#content').innerHTML =
    `<section aria-labelledby="overview-metrics-title">
      <div class="data-group-heading"><h2 id="overview-metrics-title">关键指标</h2><a href="#sources">统计口径 ↗</a></div>
      <div class="stats-grid">${cards.map(([symbol, title, value, unit, description, foot, view]) => `
        <section class="stat-card${view === firstReportsRoute ? ' stat-card-linked' : ''}">
          <div class="stat-top"><h3>${title}</h3><span class="stat-icon">${icon(symbol)}</span></div>
          <div class="stat-value">${value ?? '—'}${value == null ? '' : `<span class="unit">${unit}</span>`}</div>
          <p class="stat-hint">${description}</p>
          <div class="stat-foot">${foot}${view ? `<a href="#${view}" aria-label="查看${title}明细">↗</a>` : ''}</div>
        </section>`).join('')}</div>
    </section>
    <div class="notice-strip"><span class="notice-icon">!</span><span>${m.report_failures + m.order_issues ? `有 ${number(m.report_failures)} 份报告异常、${number(m.order_issues)} 笔订单需要核查。` : '当前范围没有报告或订单异常。'} 历史模型失败尝试单独归类，已解锁数量不作为实收依据。</span><a href="#issues">查看异常 →</a></div>
    <div class="overview-grid"><section class="panel"><div class="panel-header"><div><h3>报告生成概况</h3><p class="muted">按创建日期统计 · 图表最多展示最近 30 天</p></div><div class="legend"><span>报告</span><span class="failed">当前异常</span></div></div><div class="panel-body">${chart}<div class="chart-caption"><span>数据来源：life_reports</span><a href="#reports">查看报告明细 ↗</a></div></div></section>
    <section class="panel"><div class="panel-header"><div><h3>访问转化</h3><p class="muted">每一步都按访问次数计</p></div><a href="#visits">明细 ↗</a></div><div class="panel-body">${[
      ['访问 H5', m.visits],
      ['提交出生信息', m.submitted],
      ['查看免费预览', m.seen],
    ]
      .map(
        ([name, value]) =>
          `<div class="funnel-row"><div class="funnel-label">${name}<strong>${number(value)} 次</strong></div><div class="track"><span style="width:${m.visits ? Math.min(100, (value / m.visits) * 100) : 0}%"></span></div></div>`,
      )
      .join(
        '',
      )}<p class="funnel-note">每次访问在各阶段最多计一次，保留最近 30 天。</p></div></section></div>
    <div class="overview-grid"><section class="panel table-panel"><div class="panel-header"><div><h3>流量从哪里来</h3><p class="muted">渠道与活动标签 · ${channels.length ? '按访问人数排序' : '等待访问记录'}</p></div><a href="#visits">全部访问 →</a></div>${
      channels.length
        ? table(
            ['来源 / 活动', '访问人数', '访问次数', '提交次数', '预览次数'],
            channels
              .slice(0, 5)
              .map(
                (row) =>
                  `<tr><td><div class="source-cell"><span class="channel-icon">${esc((row.source || '?').slice(0, 1).toUpperCase())}</span><div>${sourceCell(row)}</div></div></td><td>${number(row.visitors)}</td><td>${number(row.visits)}</td><td>${number(row.submitted)}</td><td>${number(row.seen)}</td></tr>`,
              ),
          )
        : empty('暂无渠道记录')
    }<div class="table-footer">各渠道分别去重，同一访客可能出现在多个渠道。未标记表示链接缺少来源参数。</div></section>
    <section class="panel"><div class="panel-header"><div><h3>模型调用记录</h3><p class="muted">关联当前 H5 报告的实际调用</p></div><a href="#calls">查看 →</a></div><div class="panel-body"><div class="detail-fields"><div><p class="field-label">调用次数</p><h2>${number(m.calls)}</h2></div><div><p class="field-label">未通过的尝试</p><h2>${number(m.failed_calls)}</h2></div><div><p class="field-label">已记录 Token</p><h2>${number(m.tokens)}</h2></div><div><p class="field-label">上游未返回用量</p><h2>${number(m.missing_usage)}</h2></div></div><p class="funnel-note">一次失败尝试可能被后续重试修复。用量未返回时不估算消耗或费用。</p></div></section></div>
    <section class="panel table-panel"><div class="panel-header"><div><h3>最近创建的报告</h3><p class="muted">查看状态，进入详情追踪来源与处理记录</p></div><a href="#reports">全部报告 →</a></div>${reportTable(reports)}</section>`;
}
const notes = {
  visits: '每行是一次访问，保留最近 30 天。停留只累计页面在前台可见的时间。最后记录以服务器收到的上报为准。',
  reports: '按报告创建时间筛选。首次来源、活动和地区取创建时保存的值。',
  orders:
    '按建单时间筛选。历史缺少建单时间时使用报告创建时间。来源筛选使用建单来源。',
  calls: '按调用时间筛选；只展示 H5 关联调用。历史未记录的原因、耗时显示未知。',
  issues: '报告/订单按创建时间、模型尝试按调用时间筛选；“异常记录”与“异常报告数”是不同口径。',
  audit: '按管理员操作时间筛选；“已处理”仅表示内部跟进进度，不代表付款或生成成功。',
};
const recordUnits = {
  visits: '次访问', reports: '份报告', orders: '笔订单', calls: '次调用', issues: '条异常记录', audit: '条操作记录',
};
function renderRecords(data) {
  const kind = state.view;
  const verified = kind === 'orders' && state.timeBasis === 'verified';
  const note = verified
    ? '只查看正式渠道核验到账的订单，按核验时间筛选。历史缺核验时间的订单可在全部记录中查看。'
    : notes[kind];
  let recordsViewLink = '';
  if (state.firstReportsOnly) {
    recordsViewLink = '<a href="#reports">查看全部报告 ↗</a> ';
  } else if (kind === 'orders') {
    recordsViewLink = `<a href="#${verified ? 'orders' : verifiedOrdersRoute}">${verified ? '按建单时间' : '按核验时间'} ↗</a> `;
  }
  const sources = [...data.source_options];
  const selectedSource = state.source === '__untagged' ? '' : state.source;
  if (state.source && !sources.includes(selectedSource)) sources.push(selectedSource);
  const headers = {
    visits: ['访客与访问时间', '本次访问来源', '填写与转化', '前台停留', '最后记录', '关联报告'],
    orders: ['订单 / 报告', '报告首次来源', '建单来源', '金额', '环境', '支付状态', '建单时间', '核验时间'],
    calls: ['请求 / 报告', '阶段 / 内容', '模型', '校验', 'Token 输入 / 输出', '耗时', '调用时间'],
    issues: ['异常分类', '关联报告', '来源渠道', '状态 / 原因', '记录时间'],
    audit: ['操作 / 管理员', '关联报告', '结果', '处理原因', '操作时间'],
  };
  const renderRow = (row) => {
    if (kind === 'visits') {
      const progress = row.form_progress === 'form_progress_complete' && !row.submitted_at
        ? '已填完 · 暂无提交记录'
        : formProgress[row.form_progress];
      const reports = JSON.parse(row.report_ids || '[]').map((id) => reportLink({ report_id: id })).join('');
      return `<tr>
        <td><div class="visit-record-id"><span class="mono">${esc(row.visitor_number || '暂无编号')}</span><small>访问时间 ${date(row.created)}</small>${visitLink(row.id)}</div>${row.dropped_events ? `<small>轨迹缺失 ${number(row.dropped_events)} 条</small>` : ''}</td>
        <td>${sourceCell(row)}</td>
        <td>${badge(row.status)}${progress ? `<small class="visit-form-status">${esc(progress)}</small>` : ''}</td>
        <td>${duration(row.visible_ms)}</td>
        <td class="visit-last-record">
          <strong>${esc(visitPages[row.last_page] || '未采集')}</strong>
          ${visitActions[row.last_action] ? `<small>操作 ${esc(visitActions[row.last_action])}</small>` : ''}
          ${visitStates[row.last_state] ? `<small>${esc(visitStates[row.last_state])}</small>` : ''}
          ${row.last_activity_at ? `<small>接收于 ${fullDate(row.last_activity_at)}</small>` : ''}
        </td>
        <td>${row.reports ? `${number(row.reports)} 份` : '未关联'}${reports}</td>
      </tr>`;
    }
    if (kind === 'orders') {
      const firstSource = sourceCell({
        source: row.report_source, campaign: row.report_campaign,
        region_code: row.report_region_code, attribution: row.report_attribution,
      });
      return `<tr><td><strong class="mono">${esc(row.id)}</strong>${reportLink(row)}${visitorId(row)}<small>${esc(row.order_number || '尚无平台单号')}</small></td><td>${firstSource}</td><td>${sourceCell(row)}</td><td><strong>฿ ${money(row.amount)}</strong></td><td>${badge(row.environment)}</td><td>${badge(row.status)}</td><td>${date(row.created)}</td><td>${date(row.paid_at)}</td></tr>`;
    }
    if (kind === 'calls')
      return `<tr><td><span class="mono" title="${esc(row.request_id)}">${esc(short(row.request_id) || '未返回请求号')}</span>${reportLink(row)}${visitorId(row)}</td><td>${esc(label(row.phase))}<small>${esc(row.reading)}</small></td><td>${esc(row.provider)}<small>${esc(row.model)}</small></td><td>${badge(row.status)}<small title="${esc(row.code)}">${esc(label(row.code))}</small></td><td>${row.usage_received ? number(row.prompt_tokens) + ' / ' + number(row.completion_tokens) : '未返回用量'}<small>缓存命中 ${number(row.cached_tokens)}</small></td><td>${row.duration_ms == null ? '历史未记录' : (row.duration_ms / 1000).toFixed(1) + ' 秒'}</td><td>${date(row.created)}</td></tr>`;
    if (kind === 'issues')
      return `<tr><td><strong>${esc(label(row.category))}</strong><small>${row.category === 'model' ? '单次调用 · 报告可能已恢复' : row.category === 'request' ? row.http_status === 0 ? '客户端异常 · 无 HTTP 响应确认' : 'HTTP ' + row.http_status + ' · ' + (row.duration_ms / 1000).toFixed(2) + ' 秒' : row.category === 'runtime' ? '浏览器记录' : '当前业务状态'}</small></td><td>${reportLink(row)}${visitorId(row)}${visitLink(row.visit_id)}<small title="${esc(row.path)}">${esc(issueLocation(row) || row.name || '匿名访客')}</small></td><td>${sourceCell(row)}</td><td>${badge(row.status)}<small title="${esc(row.code)}">${esc(row.category === 'runtime' || row.code?.startsWith('server_') ? errorReason(row) : errors[row.code] || label(row.code))}</small></td><td>${date(row.created)}<small>${row.case_status ? '跟进：' + esc(label(row.case_status)) : '暂无关联报告'}</small></td></tr>`;
    return `<tr><td><strong>${esc(label(row.action))}</strong><small>${esc(row.actor)}</small></td><td>${reportLink(row)}${visitorId(row)}</td><td>${badge(row.status)}<small>${esc(label(row.code))}</small></td><td title="${esc(row.note)}">${esc(row.note)}</td><td>${date(row.created)}</td></tr>`;
  };
  const pages = Math.max(1, Math.ceil(data.total / data.page_size));
  $('#content').innerHTML =
    `<p class="data-note">${esc(note)} ${recordsViewLink}<a href="#sources">查看来源 ↗</a></p><section class="panel table-panel${kind === 'visits' ? ' visit-records' : ''}"><form id="filters" class="filters"><div class="search"><span aria-hidden="true">⌕</span><input id="search-input" aria-label="搜索记录" placeholder="搜索访客编号、报告、订单号或关键词…" value="${esc(state.q)}" maxlength="100"></div><select id="status-filter" aria-label="状态筛选"><option value="">全部状态</option>${data.facets.map((row) => `<option value="${esc(row.status)}" ${row.status === state.status ? 'selected' : ''}>${esc(label(row.status))} (${row.count})</option>`).join('')}</select>${kind !== 'audit' ? `<select id="source-filter" aria-label="来源筛选"><option value="">全部来源</option>${sources.map((source) => `<option value="${esc(source || '__untagged')}" ${(source || '__untagged') === state.source ? 'selected' : ''}>${esc(source || '未标记 / 未归因')}</option>`).join('')}</select>` : ''}<button class="button" type="submit">查询</button><button class="button" id="clear-filters" type="button">重置</button><button id="export" type="button" class="button export">↓ 导出当前页</button></form><div class="summary-line"><span>筛选结果 <strong>${number(data.total)}</strong> ${recordUnits[kind]}</span>${kind === 'issues' ? '<span>模型尝试与当前业务异常分别标注</span>' : ''}</div>${kind === 'reports' ? reportTable(data.items) : data.items.length ? table(headers[kind], data.items.map(renderRow)) : empty('没有符合条件的记录')}<div class="table-footer"><span>每页 ${data.page_size} 条</span><div class="pagination"><button id="previous-page" class="button" ${state.page <= 1 ? 'disabled' : ''}>上一页</button><span>${state.page} / ${pages}</span><button id="next-page" class="button" ${state.page >= pages ? 'disabled' : ''}>下一页</button></div></div></section>`;
  if (kind === 'issues')
    $('#status-filter').insertAdjacentHTML(
      'afterend',
      `<select id="category-filter" aria-label="异常分类"><option value="">全部异常分类</option>${['report', 'payment', 'model', 'request', 'runtime'].map((value) => `<option value="${value}" ${state.category === value ? 'selected' : ''}>${label(value)}</option>`).join('')}</select>`,
    );
  if (['reports', 'issues'].includes(kind))
    $('#status-filter').insertAdjacentHTML(
      'afterend',
      `<select id="case-filter" aria-label="处理进度"><option value="">全部处理进度</option>${['untracked', 'open', 'investigating', 'resolved'].map((value) => `<option value="${value}" ${state.caseStatus === value ? 'selected' : ''}>${label(value)}</option>`).join('')}</select>`,
    );
  $('#filters').addEventListener('submit', (event) => {
    event.preventDefault();
    state.q = $('#search-input').value.trim();
    state.status = $('#status-filter').value;
    state.source = $('#source-filter')?.value || '';
    state.category = $('#category-filter')?.value || '';
    state.caseStatus = $('#case-filter')?.value || '';
    state.page = 1;
    loadView();
  });
  $('#clear-filters').addEventListener('click', () => {
    state.q = '';
    state.status = '';
    state.source = '';
    state.category = '';
    state.caseStatus = '';
    state.page = 1;
    loadView();
  });
  $('#previous-page').addEventListener('click', () => {
    state.page--;
    loadView();
  });
  $('#next-page').addEventListener('click', () => {
    state.page++;
    loadView();
  });
  $('#export').addEventListener('click', exportPage);
}
function renderSources(items) {
  $('#content').innerHTML =
    `<p class="data-note">以下均为当前业务表与调用链的真实口径。空值表示未知，不用演示数据填充。</p><div class="source-grid">${items.map((row, index) => `<section class="panel source-card"><span class="source-number">0${index + 1}</span><h3>${esc(row.name)}</h3><code>${esc(row.table)}</code><p>${esc(row.rule)}</p><small>写入来源：${esc(row.origin)}</small></section>`).join('')}</div>`;
}
function exportPage() {
  const items = state.records?.items || [];
  if (!items.length) {
    toast('当前页没有可导出的数据');
    return;
  }
  const keys = Object.keys(items[0]);
  const columnNames = {
    id: '记录编号',
    report_id: '报告编号',
    report_exists: '关联报告仍可查询',
    created: '创建时间(Unix秒)',
    name: '用户填写姓名',
    visitor: '匿名浏览器标识',
    visitor_number: '访客编号',
    region_code: '首次访问地区标签',
    entry_region: '本次访问地区标签',
    first_visit_date: '首次访问日期（北京时间）',
    last_page: '最后页面',
    last_action: '最后操作',
    last_activity_at: '最后记录时间(服务器接收Unix秒)',
    last_state: '最后上报页面状态',
    form_progress: '最近填写进度',
    visible_ms: '累计前台可见停留(毫秒)',
    dropped_events: '待发队列溢出条数',
    visit_id: '关联访问编号',
    landing_visit_id: '建单访问编号',
    source: state.view === 'orders' ? '建单来源' : '来源渠道',
    report_source: '报告首次来源',
    report_campaign: '报告首次活动',
    report_region_code: '报告首次投放地区',
    report_attribution: '报告首次来源状态',
    campaign: '活动标签',
    status: '业务状态代码',
    case_status: '内部处理进度',
    amount: '订单金额(分)',
    currency: '币种',
    environment: '支付环境',
    order_number: '平台单号',
    paid_at: '核验到账时间(Unix秒)',
    duration_ms: '耗时(毫秒)',
    code: '结果或错误码',
    note: '处理备注',
    actor: '管理员',
    action: '操作代码',
    prompt_tokens: '输入Token',
    completion_tokens: '输出Token',
    cached_tokens: '缓存Token',
  };
  const cell = (value) => {
    const text = String(value ?? '');
    return '"' + (/^[\s]*[=+@\-]/.test(text) ? "'" : '') + text.replaceAll('"', '""') + '"';
  };
  const csv =
    '\ufeff' +
    [
      keys.map((key) => cell(columnNames[key] || key)).join(','),
      ...items.map((row) => keys.map((key) => {
        const dictionary = { last_page: visitPages, last_action: visitActions, last_state: visitStates, form_progress: formProgress }[key];
        return cell(dictionary ? dictionary[row[key]] || '未采集' : row[key]);
      }).join(',')),
    ].join('\r\n');
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = `FATE-${state.view}-page${state.page}.csv`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
const field = (name, value, source) =>
  `<div><div class="field-label">${esc(name)}</div><div class="field-value">${esc(value)}<small>${esc(source)}</small></div></div>`;
async function openVisit(id, page = 1) {
  const request = Symbol();
  state.detailRequest = request;
  state.detail = null;
  $('#detail-title').textContent = '访问轨迹';
  $('#detail-content').innerHTML = '<div class="loading">正在读取轨迹…</div>';
  if (!$('#detail-dialog').open) $('#detail-dialog').showModal();
  try {
    const data = await api('/visits/' + encodeURIComponent(id) + '?page=' + page);
    if (state.detailRequest !== request || !state.session) return;
    const v = data.visit, pages = Math.max(1, Math.ceil(data.total / data.page_size));
    const hasLastRecord = v.last_page || v.last_action || v.last_state || v.last_activity_at;
    const profiles = data.submitted_profiles || [];
    $('#detail-title').textContent = (v.visitor_number || '暂无编号') + ' · 访问轨迹';
    $('#detail-content').innerHTML = `<div class="visit-detail-meta"><span>访问编号 <code>${esc(v.id)}</code></span><span>北京时间</span></div>
      <div class="visit-detail-summary">
        <section class="detail-section"><h3>本次访问</h3><div class="detail-fields">
          ${field('访问时间', fullDate(v.created), '')}
          ${field('前台停留总时长', duration(v.visible_ms), '')}
          ${field('填写进度', formProgress[v.form_progress] || '未采集', '')}
          ${field('资料提交', v.submitted_at ? '已提交' : '暂无提交记录', v.submitted_at ? fullDate(v.submitted_at) : '')}
        </div></section>
        <section class="detail-section"><h3>最后记录</h3>${hasLastRecord ? `<div class="detail-fields">
          ${field('最后页面', visitPages[v.last_page] || '未采集', '')}
          ${field('最后操作', visitActions[v.last_action] || '未采集', '')}
          ${field('当时页面状态', visitStates[v.last_state] || '未采集', '')}
          ${field('服务器接收时间', v.last_activity_at ? fullDate(v.last_activity_at) : '未采集', '')}
        </div>` : '<p class="visit-detail-note muted">这条访问没有采到最后的页面和操作。</p>'}</section>
      </div>
      ${v.dropped_events ? `<p class="error-banner">该访问有 ${number(v.dropped_events)} 条事件因浏览器待发队列溢出而未保留，轨迹不完整。</p>` : ''}
      <section class="detail-section visit-data-section">
        <header class="visit-section-heading"><h3>页面停留时间</h3><p>只累计页面在前台可见的时间。同一页面多次进入会合计。</p></header>
        ${data.pages.length ? table(['页面', '进入次数', '前台停留时间'], data.pages.map(row => `<tr><td>${esc(visitPages[row.page] || row.page)}</td><td>${number(row.entries)} 次</td><td>${duration(row.visible_ms)}</td></tr>`), true) : '<p class="visit-detail-note muted">这条访问没有采到页面停留时间。</p>'}
      </section>
      <section class="detail-section"><h3>已提交的出生资料</h3>${profiles.length
        ? table(['出生日期', '出生时间', '出生地点', '关联报告'], profiles.map(row =>
            `<tr><td>${esc(row.birth_date || '未记录')}</td><td>${esc(row.birth_time || (row.birth_time_unknown ? '不清楚时间' : '未记录'))}</td><td>${esc(row.birthplace || '未记录')}</td><td>${reportLink(row)}</td></tr>`), true)
        : `<p class="visit-detail-note muted">${v.submitted_at ? '提交已记录，暂无关联资料可查看。' : '暂无已提交的资料。'}</p>`}
      ${v.reports > profiles.length && profiles.length ? `<p class="visit-detail-note muted">显示 ${number(profiles.length)} 份，按报告创建时间排序。</p>` : ''}
      </section>
      <section class="detail-section visit-data-section">
        <header class="visit-section-heading"><h3>操作轨迹 · ${number(data.total)} 条记录</h3><p>操作时间来自浏览器，接收时间是服务器收到上报的时间。</p></header>
        ${data.events.length ? table(['页面与操作', '当时页面状态', '本次进入累计停留', '操作与接收时间'], data.events.map(row => `<tr><td>${esc(visitPages[row.page] || row.page)}<small>${esc(visitActions[row.action] || row.action)}${row.kind === 'state' ? ' · 页面状态变化' : ''}</small></td><td>${esc(visitStates[row.state] || row.state)}</td><td>${duration(row.visible_ms)}</td><td>操作 ${fullDate(row.occurred_at)}<small>接收 ${fullDate(row.received_at)}</small></td></tr>`), true) : '<p class="visit-detail-note muted">这条访问没有采到操作轨迹。</p>'}
        ${pages > 1 || page > 1 ? `<div class="pagination visit-detail-pagination"><button class="button" data-visit="${esc(id)}" data-visit-page="${page - 1}" ${page <= 1 ? 'disabled' : ''}>上一页</button><span>${page} / ${pages}</span><button class="button" data-visit="${esc(id)}" data-visit-page="${page + 1}" ${page >= pages ? 'disabled' : ''}>下一页</button></div>` : ''}
      </section>
      <section class="detail-section"><h3>关联失败 · 最近 ${data.failures.length} 条</h3>${data.failures.length ? table(['出错环节', '原因', '记录时间'], data.failures.map(row => `<tr><td>${esc(issueLocation(row))}<small>${row.category === 'runtime' ? '前端程序错误' : row.http_status === 0 ? '客户端异常' : 'HTTP ' + row.http_status}</small></td><td>${esc(errorReason(row))}<small class="mono">${esc(row.code)}</small></td><td>${fullDate(row.created)}</td></tr>`), true) : '<p class="visit-detail-note muted">暂无已记录的关联失败，不代表从未发生错误。</p>'}</section>`;
  } catch (error) {
    if (state.detailRequest === request) $('#detail-content').innerHTML = `<div class="error-banner">${esc(error.message)}</div>`;
  }
}
async function openDetail(id) {
  const request = Symbol();
  state.detailRequest = request;
  $('#detail-content').innerHTML = '<div class="loading">正在读取详情…</div>';
  if (!$('#detail-dialog').open) $('#detail-dialog').showModal();
  try {
    const data = await api('/reports/' + encodeURIComponent(id));
    if (state.detailRequest !== request || !state.session) return;
    state.detail = data;
    renderDetail(data);
  } catch (error) {
    if (state.detailRequest === request)
      $('#detail-content').innerHTML = `<div class="error-banner">${esc(error.message)}</div>`;
  }
}
function reportDocumentSection(editions) {
  const available = Object.keys(reportEditionNames).filter((edition) => editions?.includes(edition));
  const controls = available.map((edition) => {
    const name = reportEditionNames[edition];
    return `<button type="button" class="button" data-report-edition="${edition}">查看${name}</button>
      <button type="button" class="button" data-report-edition="${edition}" data-report-pdf>下载${name} PDF</button>`;
  }).join('');
  return `<section class="detail-section"><h3>报告正文</h3>
    ${controls ? `<div class="report-document-tools">${controls}</div>
      <p class="report-document-status muted" role="status"></p>
      <iframe class="report-document-frame" title="报告正文" sandbox referrerpolicy="no-referrer" hidden></iframe>`
    : '<p class="panel-body muted">正文生成并保存后可查看和下载。</p>'}
  </section>`;
}

async function openReportDocument(button) {
  if (!state.detail || button.disabled) return;
  const reportId = state.detail.report.id;
  const request = state.detailRequest;
  const edition = button.dataset.reportEdition;
  const pdf = button.hasAttribute('data-report-pdf');
  const section = button.closest('.detail-section');
  const controls = section.querySelectorAll('[data-report-edition]');
  const status = section.querySelector('.report-document-status');
  const frame = section.querySelector('.report-document-frame');
  const current = () => request === state.detailRequest && section.isConnected && $('#detail-dialog').open;
  for (const control of controls) control.disabled = true;
  status.classList.remove('error-text');
  status.textContent = pdf ? '正在准备 PDF…' : '正在读取报告正文…';
  try {
    const [report, runtime] = await Promise.all([
      api(`/reports/${encodeURIComponent(reportId)}/content?edition=${encodeURIComponent(edition)}`),
      loadReportRuntime(),
    ]);
    if (!current()) return;
    const payload = JSON.stringify(report);
    if (pdf) {
      const result = await runtime.exportDocument(payload, 'pdf', { showSaveDialog: false });
      if (current()) status.textContent = {
        saved: 'PDF 已保存。',
        downloaded: 'PDF 下载已开始。',
        cancelled: '已取消保存。',
      }[result];
    } else {
      frame.title = reportEditionNames[edition] + '正文';
      frame.srcdoc = runtime.renderReportHtml(payload);
      frame.hidden = false;
      status.textContent = '';
    }
  } catch (error) {
    if (current()) {
      status.classList.add('error-text');
      status.textContent = errors[error.message] || error.message;
    }
  } finally {
    for (const control of controls) control.disabled = false;
  }
}

function renderDetail(data) {
  const r = data.report,
    p = data.input.profile || {},
    order = data.payment[0];
  $('#detail-title').textContent = (r.name || '匿名访客') + ' · 报告详情';
  const canRetry =
    !['queued', 'generating'].includes(r.status) &&
    r.full_state !== 'ready' &&
    (r.preview_state !== 'ready' || r.unlocked);
  const calls = data.calls.map(
    (row) =>
      `<tr><td>${esc(label(row.phase))}<small>${esc(row.reading)}</small></td><td>${badge(row.status)}<small>${esc(label(row.code))}</small></td><td>${row.duration_ms == null ? '未记录' : (row.duration_ms / 1000).toFixed(1) + ' 秒'}</td><td>${date(row.created)}</td></tr>`,
  );
  $('#detail-content').innerHTML =
    `<p class="detail-id mono">${esc(r.id)}</p><div class="detail-actions"><button class="button" data-action="check_payment" ${order && order.environment !== 'simulation' ? '' : 'disabled'}>核对到账</button><button class="button" data-action="retry_report" ${canRetry ? '' : 'disabled'} title="已解锁的失败报告可重试；未解锁只可重试免费预览">重试失败报告</button><button class="primary" data-action="note">添加处理记录</button><button class="button" data-report="${esc(r.id)}">↻ 刷新详情</button></div>
    ${reportDocumentSection(data.content_editions)}
    <section class="detail-section"><h3>报告状态与来源 ${badge(r.status)}</h3><div class="detail-fields">${field('预览状态', label(r.preview_state), 'life_reports.preview_state')}${field('完整报告', label(r.full_state), 'life_reports.full_state')}${field('权限', r.unlocked ? '已解锁（不等同于实收）' : '未解锁', 'life_reports.unlocked')}${field('访客编号', r.visitor_number || '暂无编号', 'landing_visitors.visitor_number')}${field('创建时间', fullDate(r.created), 'life_reports.created')}${field('首次来源', sourceName(r), '报告创建时记录')}${field('首次活动', r.campaign || '未记录', '报告创建时记录')}${field('首次投放地区', r.region_code || '未知', '首次链接的地区标签')}${field('已完成内容', `${data.completed_chapters.length} 个章节${data.has_plan ? ' + 行动计划' : ''}`, 'life_reports.chapters / plan')}${field('内部跟进', label(data.case.status), 'admin_cases.status')}</div><details><summary>查看当前生成进度记录</summary><pre>${esc(JSON.stringify(data.progress, null, 2))}</pre></details></section>
    <section class="detail-section"><h3>用户提交信息</h3><div class="detail-fields">${field('姓名', p.display_name || '未填写', 'input.profile.display_name')}${field('报告语言', label(p.language), 'input.profile.language')}${field('出生日期', p.birth_date || '未记录', 'input.profile.birth_date')}${field('出生时间', p.birth_time || '未知', 'input.profile.birth_time')}${field('出生地', p.birthplace || '未记录', 'input.profile.birthplace')}${field('时区', p.timezone || '未记录', 'input.profile.timezone')}</div></section>
    <section class="detail-section"><h3>订单与服务端回执 ${order ? badge(order.status) : ''}</h3>${order ? `<div class="detail-fields">${field('订单编号', order.id, 'life_card_payments.reference')}${field('订单金额', 'THB ' + money(order.amount), 'life_card_payments.amount / 100')}${field('建单来源', sourceName(order), 'life_card_payments.landing_source')}${field('建单访问编号', order.landing_visit_id || '未归因', 'life_card_payments.landing_visit_id')}${field('平台单号', order.order_number || '未返回', 'sunlands_order_number')}${field('运行环境', label(order.environment), '支付网关与商户类型')}${field('到账核验', label(order.status), 'paymentStatus + provider_order')}${field('核验到账时间', fullDate(order.paid_at), 'sunlands_order.paidAt')}</div><details><summary>查看已脱敏的建单与查单回执</summary><pre>${esc(JSON.stringify(data.receipt, null, 2))}</pre></details>` : '<div class="panel-body muted">没有关联支付订单。报告解锁本身不能证明收款。</div>'}</section>
    <section class="detail-section"><h3>模型调用 · 最近 ${data.calls.length} 条</h3>${calls.length ? table(['阶段', '校验 / 原因', '耗时', '时间'], calls, true) : '<div class="panel-body muted">暂无与该报告关联的调用记录。</div>'}</section>
    <section class="detail-section"><h3>管理员处理记录 · 最近 ${data.audit.length} 条</h3><div class="timeline">${data.audit.length ? data.audit.map((row) => `<div class="timeline-item"><strong>${esc(row.actor)} · ${esc(label(row.action))} ${badge(row.status)}</strong><p>${esc(row.note)}</p><p>结果：${esc(errors[row.code] || label(row.code))}</p><small>${fullDate(row.created)}</small></div>`).join('') : '<p class="muted">还没有处理记录。</p>'}</div></section>`;
}
function openAction(action) {
  if (!state.detail) return;
  state.action = action;
  state.requestId = crypto.randomUUID();
  $('#action-title').textContent = label(action);
  $('#action-description').textContent = {
    check_payment: '重新向支付网关查询这笔已有订单，校验到账后由原业务流程更新报告权益。',
    retry_report: '重试当前报告的失败部分，已完成内容保留。可能产生模型调用费用。',
    note: '记录本次跟进情况，供之后查看与交接。',
  }[action];
  $('#case-status-wrap').hidden = action !== 'note';
  $('#case-status').value =
    state.detail.case.status === 'untracked' ? 'open' : state.detail.case.status;
  $('#action-note').value = '';
  $('#action-error').textContent = '';
  $('#confirm-action').disabled = false;
  $('#cancel-action').disabled = false;
  $('#action-dialog').showModal();
  $('#action-note').focus();
}
$('#login-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const button = $('#login-form button');
  button.disabled = true;
  $('#login-error').textContent = '';
  try {
    state.session = await api('/login', {
      method: 'POST',
      body: { username: $('#username').value.trim(), password: $('#password').value },
    });
    $('#password').value = '';
    await openWorkspace();
  } catch (error) {
    $('#login-error').textContent = error.message;
  } finally {
    button.disabled = false;
  }
});
async function logout() {
  try {
    await api('/logout', { method: 'POST' });
    showLogin();
  } catch (error) {
    toast(error.message);
  }
}
$('#logout').addEventListener('click', logout);
$('#mobile-logout').addEventListener('click', logout);
$('#refresh').addEventListener('click', async () => {
  const button = $('#refresh');
  button.disabled = true;
  try {
    await loadView({ refresh: true });
  } finally {
    button.disabled = false;
  }
});
$('#days').addEventListener('change', () => {
  state.days = Number($('#days').value);
  state.page = 1;
  loadView();
});
$('#visit-funnel-range').addEventListener('submit', (event) => {
  event.preventDefault();
  const start = $('#visit-range-start').value;
  const end = $('#visit-range-end').value;
  if (start > end) {
    const error = $('#visit-range-error');
    error.textContent = '开始日期不能晚于结束日期。';
    error.hidden = false;
    return;
  }
  state.visitRange = { start_date: start, end_date: end };
  loadView();
});
$('#visit-range-reset').addEventListener('click', () => {
  state.visitRange = null;
  loadView();
});
const funnelMeasureButtons = document.querySelectorAll('[data-funnel-measure]');
funnelMeasureButtons.forEach((button) => {
  button.addEventListener('click', () => {
    state.funnelMeasure = button.dataset.funnelMeasure;
    funnelMeasureButtons.forEach((option) => option.setAttribute('aria-pressed', String(option === button)));
    if (state.funnelMetrics) renderVisitFunnel(state.funnelMetrics);
  });
});
document.querySelectorAll('[data-line-range]').forEach((button) => {
  button.addEventListener('click', () => {
    state.lineRange = { preset: button.dataset.lineRange };
    loadView();
  });
});
$('#line-range-form').addEventListener('submit', (event) => {
  event.preventDefault();
  const start = $('#line-range-start').value;
  const end = $('#line-range-end').value;
  const from = lineEpoch(start);
  const until = lineEpoch(end);
  if (!Number.isFinite(from) || !Number.isFinite(until) || from < 0 || from >= until) {
    const error = $('#line-range-error');
    error.textContent = errors.admin_line_range_invalid;
    error.hidden = false;
    return;
  }
  state.lineRange = { start, end };
  loadView();
});
window.addEventListener('hashchange', () => navigate(location.hash.slice(1)));
document.addEventListener('click', (event) => {
  const visit = event.target.closest('[data-visit]');
  if (visit && !visit.disabled) openVisit(visit.dataset.visit, Number(visit.dataset.visitPage || 1));
  const report = event.target.closest('[data-report]');
  if (report) openDetail(report.dataset.report);
  const action = event.target.closest('[data-action]');
  if (action) openAction(action.dataset.action);
  const reportDocument = event.target.closest('[data-report-edition]');
  if (reportDocument) openReportDocument(reportDocument);
});
$('#close-detail').addEventListener('click', () => $('#detail-dialog').close());
$('#detail-dialog').addEventListener('close', (event) => {
  if (!event.target.open) {
    state.detail = null;
    state.detailRequest = null;
    $('#detail-content').replaceChildren();
  }
});
$('#cancel-action').addEventListener('click', () => $('#action-dialog').close());
$('#action-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const note = $('#action-note').value.trim();
  if (!note) return;
  $('#confirm-action').disabled = true;
  $('#cancel-action').disabled = true;
  $('#action-error').textContent = '';
  const id = state.detail.report.id;
  try {
    const result = await api('/reports/' + encodeURIComponent(id) + '/actions', {
      method: 'POST',
      body: {
        request_id: state.requestId,
        action: state.action,
        note,
        case_status: $('#case-status').value,
      },
    });
    $('#action-dialog').close();
    toast(state.action === 'retry_report' && result.code === 'queued'
      ? '已加入生成队列，稍后刷新查看进度。'
      : label(result.code) + (state.action === 'retry_report' ? '，稍后刷新查看结果。' : ''));
    await openDetail(id);
    await loadView({ refresh: true });
  } catch (error) {
    $('#action-error').textContent = error.message;
  } finally {
    $('#confirm-action').disabled = false;
    $('#cancel-action').disabled = false;
  }
});
$('#action-dialog').addEventListener('cancel', (event) => {
  if ($('#confirm-action').disabled) event.preventDefault();
});
(async () => {
  try {
    state.session = await api('/session');
    await openWorkspace();
  } catch (error) {
    showLogin();
    if (!error.message.includes('登录已过期')) $('#login-error').textContent = error.message;
  }
})();
