import { useEffect, useId, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { ArrowRight, CreditCard, Link, X } from "lucide-react";
import { lifeApi, lifeReportUrl, type LifeReport } from "../lib/lifeReport";
import { ApiError } from "../lib/reading";

const copy = {
  zh: {
    title: "确认订单", demo: "支付演示", order: "演示订单号", once: "一次性解锁", close: "返回报告",
    card: "信用卡 / 借记卡",
    cardNumber: "卡号", expiry: "有效期", securityCode: "安全码", fillCard: "填入测试卡",
    cardHint: "点击「填入测试卡」体验付款流程。",
    cardConfirm: "模拟支付",
    waiting: "等待模拟付款", link: "复制本机继续链接", copied: "链接已复制，可在本浏览器继续。",
    payso: "Payso 测试", paysoOpen: "前往 Payso 测试付款", preparing: "正在创建测试订单…",
    paysoHint: "在新标签页选择银行卡并使用 Payso 测试卡。保留此页面，确认付款后会自动解锁。",
    paysoWaiting: "等待 Payso 确认付款", retry: "重试",
  },
  th: {
    title: "ยืนยันคำสั่งซื้อ", demo: "ทดลองชำระเงิน", order: "เลขคำสั่งซื้อทดสอบ", once: "จ่ายครั้งเดียว", close: "กลับไปที่รายงาน",
    card: "บัตรเครดิต / เดบิต",
    cardNumber: "หมายเลขบัตร", expiry: "วันหมดอายุ", securityCode: "รหัสความปลอดภัย", fillCard: "กรอกข้อมูลบัตรทดสอบ",
    cardHint: "กดกรอกข้อมูลบัตรทดสอบเพื่อทดลองชำระเงิน",
    cardConfirm: "จำลองการชำระ",
    waiting: "รอจำลองการชำระเงิน", link: "คัดลอกลิงก์สำหรับเปิดต่อ", copied: "คัดลอกแล้ว เปิดต่อได้ในเบราว์เซอร์นี้",
    payso: "ทดสอบกับ Payso", paysoOpen: "ไปทดสอบชำระเงินกับ Payso", preparing: "กำลังสร้างคำสั่งซื้อทดสอบ…",
    paysoHint: "เลือกชำระด้วยบัตรและใช้บัตรทดสอบของ Payso ในแท็บใหม่ เปิดหน้านี้ไว้ ระบบจะปลดล็อกรายงานเมื่อยืนยันการชำระเงิน",
    paysoWaiting: "รอ Payso ยืนยันการชำระเงิน", retry: "ลองอีกครั้ง",
  },
};

type PaysoOrder = { action: string; fields: Record<string, string> };

function PaysoCardCheckout({ report, onConfirm }: { report: LifeReport; onConfirm: () => void }) {
  const { id, input: { profile: { language } } } = report;
  const c = copy[language];
  const [order, setOrder] = useState<PaysoOrder>();
  const [error, setError] = useState("");
  const [attempt, setAttempt] = useState(0);
  const [submitted, setSubmitted] = useState(false);
  const confirm = useRef(onConfirm);
  useEffect(() => { confirm.current = onConfirm; }, [onConfirm]);

  useEffect(() => {
    const controller = new AbortController();
    const path = `/api/life-reports/${id}/payment`;
    let timer: number;
    async function check() {
      let delay = 5000;
      try {
        const result = await lifeApi<{ paid: boolean }>(`${path}/check`, language, controller.signal, {});
        if (controller.signal.aborted) return;
        if (result.paid) { confirm.current(); return; }
        setError("");
      } catch (cause) {
        if (controller.signal.aborted) return;
        if (cause instanceof ApiError) delay = Math.max(delay, cause.retryAfterMs ?? 0);
        setError(cause instanceof Error ? cause.message : String(cause));
      }
      timer = window.setTimeout(() => void check(), delay);
    }
    void lifeApi<PaysoOrder>(path, language, controller.signal, {}).then(value => {
      if (controller.signal.aborted) return;
      setOrder(value);
      timer = window.setTimeout(() => void check(), 5000);
    }).catch(cause => {
      if (!controller.signal.aborted) setError(cause instanceof Error ? cause.message : String(cause));
    });
    return () => { controller.abort(); clearTimeout(timer); };
  }, [id, language, attempt]);

  return <div className="mt-4">
    <p className="flex items-center gap-2 text-sm font-semibold text-cream"><CreditCard size={17} aria-hidden="true" />{c.card}</p>
    <p className="mt-2 text-[11px] leading-5 text-lavender">{c.paysoHint}</p>
    {order ? <form action={order.action} method="post" target="_blank" rel="noopener" onSubmit={() => setSubmitted(true)}>
      {Object.entries(order.fields).map(([name, value]) => <input key={name} type="hidden" name={name} value={value} />)}
      <p className="mt-2 text-[10px] text-lavender">{c.order} <span className="font-mono">{order.fields.refno}</span></p>
      {submitted && <p className="mt-2 text-center text-xs text-gold" role="status">{c.paysoWaiting}</p>}
      <button type="submit" className="primary" data-testid="life-checkout-confirm">{c.paysoOpen}<ArrowRight size={16} aria-hidden="true" /></button>
    </form> : !error && <p className="mt-3 text-xs text-gold" role="status">{c.preparing}</p>}
    {error && <p className="mt-3 text-xs text-[#f2a6af]" role="alert">{error}</p>}
    {!order && error && <button type="button" className="report-secondary mt-2" onClick={() => { setError(""); setAttempt(value => value + 1); }}>{c.retry}</button>}
  </div>;
}

export function ReportCheckoutDialog({ report, product, onClose, onConfirm }: {
  report: LifeReport;
  product: string;
  onClose: () => void;
  onConfirm: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const title = useId();
  const [testCardReady, setTestCardReady] = useState(false);
  const [linkStatus, setLinkStatus] = useState<"copied" | "manual">();
  const c = copy[report.input.profile.language];
  const payso = report.price.mode === "payso_test";
  const resumeUrl = new URL(lifeReportUrl(report));
  resumeUrl.searchParams.set("checkout", "1");
  const order = `FATE-${report.id.slice(0, 12).toUpperCase()}`;

  useEffect(() => {
    const element = dialog.current;
    element?.showModal();
    return () => element?.close();
  }, []);

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(resumeUrl.href);
      setLinkStatus("copied");
    } catch {
      setLinkStatus("manual");
    }
  }

  return createPortal(
    <dialog ref={dialog} className="report-checkout-dialog p-5 text-cream" aria-labelledby={title} data-testid="life-checkout"
      onCancel={event => { event.preventDefault(); onClose(); }}>
      <div className="flex items-center justify-between gap-3">
        <span className="text-sm font-bold tracking-[0.1em] text-gold"><span aria-hidden="true">✧</span> FATE</span>
        <button type="button" className="rounded-lg bg-transparent p-2 text-lavender" aria-label={c.close} onClick={onClose}><X size={20} aria-hidden="true" /></button>
      </div>
      <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
        <h2 id={title} className="text-xl font-semibold">{c.title}</h2>
        <span className="rounded-full border border-solid border-gold/35 bg-gold/10 px-3 py-1 text-[10px] text-gold">{payso ? c.payso : c.demo}</span>
      </div>
      <div className="mt-4 rounded-xl border border-solid border-gold/25 bg-plum/70 p-3">
        <div className="flex items-center justify-between gap-4">
          <div className="min-w-0"><p className="text-sm font-semibold leading-5">{product}</p><p className="mt-1 text-[10px] text-lavender">{c.once}</p></div>
          <p className="shrink-0 text-2xl font-semibold text-gold">{report.price.display}</p>
        </div>
        {!payso && <p className="mt-3 border-0 border-t border-solid border-gold/20 pt-2 text-[10px] text-lavender">{c.order} <span className="ml-1 font-mono text-cream">{order}</span></p>}
      </div>
      {payso ? <PaysoCardCheckout report={report} onConfirm={onConfirm} /> : <>
        <div className="mt-4 rounded-xl border border-solid border-gold/25 bg-plum/70 p-3">
          <div className="flex items-center gap-2 text-gold"><CreditCard size={19} aria-hidden="true" /><p className="text-sm font-semibold">{c.card}</p></div>
          <div className="mt-3 grid grid-cols-2 gap-2 text-[11px] text-lavender">
            <label className="col-span-2 min-w-0">{c.cardNumber}
              <input className="mt-1 font-mono" type="text" readOnly tabIndex={-1} placeholder="0000 0000 0000 0000" value={testCardReady ? "4242 4242 4242 4242" : ""} />
            </label>
            <label className="min-w-0">{c.expiry}
              <input className="mt-1 font-mono" type="text" readOnly tabIndex={-1} placeholder="MM / YY" value={testCardReady ? "12 / 30" : ""} />
            </label>
            <label className="min-w-0">{c.securityCode}
              <input className="mt-1 font-mono" type="text" readOnly tabIndex={-1} placeholder="CVC / CVV" value={testCardReady ? "123" : ""} />
            </label>
          </div>
          <p className="mt-3 text-[11px] leading-5 text-lavender">{c.cardHint}</p>
          <button type="button" className="report-secondary mt-2 disabled:opacity-50" disabled={testCardReady} onClick={() => setTestCardReady(true)}>{c.fillCard}</button>
        </div>
        <p className="mt-3 text-center text-xs text-gold" role="status">{c.waiting}</p>
        <button type="button" className="primary !mt-2 disabled:cursor-not-allowed disabled:opacity-50" data-testid="life-checkout-confirm"
          disabled={!testCardReady} onClick={onConfirm}>
          {c.cardConfirm} {report.price.display}<ArrowRight size={16} aria-hidden="true" />
        </button>
      </>}
      <div className="mt-2 text-center">
        <button type="button" className="inline-flex items-center gap-2 bg-transparent p-2 text-[11px] text-lavender" onClick={() => void copyLink()}><Link size={14} aria-hidden="true" />{c.link}</button>
        {linkStatus === "copied" && <p className="text-[11px] text-gold" role="status">{c.copied}</p>}
        {linkStatus === "manual" && <input className="mt-1" type="text" aria-label={c.link} readOnly value={resumeUrl.href} onFocus={event => event.currentTarget.select()} />}
      </div>
    </dialog>, document.body,
  );
}
