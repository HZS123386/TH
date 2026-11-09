import { useEffect, useId, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { ArrowRight, CreditCard, Download, Link, QrCode, X } from "lucide-react";
import { lifeReportUrl, type LifeReport } from "../lib/lifeReport";
import qrUrl from "../../dist/assets/checkout-demo-qr.png?url";

const copy = {
  zh: {
    title: "确认订单", demo: "支付演示", order: "演示订单号", once: "一次性解锁", close: "返回报告",
    paymentMethod: "支付方式", card: "信用卡 / 借记卡", cardDetails: "银行卡信息",
    cardNumber: "卡号", expiry: "有效期", securityCode: "安全码", fillCard: "填入测试卡",
    cardHint: "点击「填入测试卡」体验付款流程。",
    cardConfirm: "模拟支付",
    waiting: "等待模拟付款", qr: "PromptPay 示例二维码", save: "保存示例二维码",
    hint: "真实付款时可用银行 App 扫码，或保存图片后从相册导入。这个二维码仅供演示。",
    confirm: "模拟付款成功", link: "复制本机继续链接", copied: "链接已复制，可在本浏览器继续。",
  },
  th: {
    title: "ยืนยันคำสั่งซื้อ", demo: "ทดลองชำระเงิน", order: "เลขคำสั่งซื้อทดสอบ", once: "จ่ายครั้งเดียว", close: "กลับไปที่รายงาน",
    paymentMethod: "วิธีชำระเงิน", card: "บัตรเครดิต / เดบิต", cardDetails: "ข้อมูลบัตร",
    cardNumber: "หมายเลขบัตร", expiry: "วันหมดอายุ", securityCode: "รหัสความปลอดภัย", fillCard: "กรอกข้อมูลบัตรทดสอบ",
    cardHint: "กดกรอกข้อมูลบัตรทดสอบเพื่อทดลองชำระเงิน",
    cardConfirm: "จำลองการชำระ",
    waiting: "รอจำลองการชำระเงิน", qr: "ตัวอย่าง QR พร้อมเพย์", save: "บันทึก QR ตัวอย่าง",
    hint: "เมื่อชำระจริง ให้สแกนด้วยแอปธนาคาร หรือบันทึกรูปแล้วเลือกจากแกลเลอรี QR นี้ใช้สาธิตเท่านั้น",
    confirm: "จำลองว่าชำระเงินสำเร็จ", link: "คัดลอกลิงก์สำหรับเปิดต่อ", copied: "คัดลอกแล้ว เปิดต่อได้ในเบราว์เซอร์นี้",
  },
};

export function ReportCheckoutDialog({ report, product, onClose, onConfirm }: {
  report: LifeReport;
  product: string;
  onClose: () => void;
  onConfirm: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const title = useId();
  const [method, setMethod] = useState<"promptpay" | "card">("promptpay");
  const [testCardReady, setTestCardReady] = useState(false);
  const [linkStatus, setLinkStatus] = useState<"copied" | "manual">();
  const c = copy[report.input.profile.language];
  const cardSelected = method === "card";
  const methods = [
    { value: "promptpay", label: "PromptPay", Icon: QrCode },
    { value: "card", label: c.card, Icon: CreditCard },
  ] as const;
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
        <span className="font-serif text-sm tracking-[0.2em] text-gold"><span aria-hidden="true">✧</span> FATE</span>
        <button type="button" className="rounded-lg bg-transparent p-2 text-lavender" aria-label={c.close} onClick={onClose}><X size={20} aria-hidden="true" /></button>
      </div>
      <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
        <h2 id={title} className="text-xl font-semibold">{c.title}</h2>
        <span className="rounded-full border border-solid border-gold/35 bg-gold/10 px-3 py-1 text-[10px] text-gold">{c.demo}</span>
      </div>
      <div className="mt-4 rounded-xl border border-solid border-gold/25 bg-plum/70 p-3">
        <div className="flex items-center justify-between gap-4">
          <div className="min-w-0"><p className="text-sm font-semibold leading-5">{product}</p><p className="mt-1 text-[10px] text-lavender">{c.once}</p></div>
          <p className="shrink-0 text-2xl font-semibold text-gold">{report.price.display}</p>
        </div>
        <p className="mt-3 border-0 border-t border-solid border-gold/20 pt-2 text-[10px] text-lavender">{c.order} <span className="ml-1 font-mono text-cream">{order}</span></p>
      </div>
      <fieldset className="m-0 mt-4 min-w-0 border-0 p-0">
        <legend className="p-0 text-xs font-semibold text-cream">{c.paymentMethod}</legend>
        <div className="mt-2 grid grid-cols-2 gap-2">
          {methods.map(({ value, label, Icon }) => (
            <label className="cursor-pointer" key={value}>
              <input type="radio" name={`${title}-method`} className="peer sr-only" checked={method === value} onChange={() => setMethod(value)} />
              <span className="flex min-h-11 items-center justify-center gap-1.5 rounded-lg border border-solid border-gold/25 px-2 py-1 text-center text-xs text-lavender peer-checked:border-gold peer-checked:bg-gold/10 peer-checked:text-cream peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-gold">
                <Icon size={15} className="shrink-0" aria-hidden="true" />{label}
              </span>
            </label>
          ))}
        </div>
      </fieldset>
      {!cardSelected ? <div className="mt-4 text-center">
          <p className="text-xs font-semibold text-cream">{c.qr}</p>
          <img className="mx-auto mt-2 block rounded-lg bg-white" src={qrUrl} width={136} height={136} alt={c.qr} />
          <a className="report-secondary mt-2" href={qrUrl} download="FATE-demo-QR.png"><Download size={14} aria-hidden="true" />{c.save}</a>
          <p className="mx-auto mt-2 max-w-xs text-[11px] leading-5 text-lavender">{c.hint}</p>
        </div> : <div className="mt-4 rounded-xl border border-solid border-gold/25 bg-plum/70 p-3">
          <div className="flex items-center gap-2 text-gold"><CreditCard size={19} aria-hidden="true" /><p className="text-sm font-semibold">{c.cardDetails}</p></div>
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
        </div>}
      <p className="mt-3 text-center text-xs text-gold" role="status">{c.waiting}</p>
      <button type="button" className="primary !mt-2 disabled:cursor-not-allowed disabled:opacity-50" data-testid="life-checkout-confirm"
        disabled={cardSelected && !testCardReady} onClick={onConfirm}>
        {cardSelected ? `${c.cardConfirm} ${report.price.display}` : c.confirm}<ArrowRight size={16} aria-hidden="true" />
      </button>
      <div className="mt-2 text-center">
        <button type="button" className="inline-flex items-center gap-2 bg-transparent p-2 text-[11px] text-lavender" onClick={() => void copyLink()}><Link size={14} aria-hidden="true" />{c.link}</button>
        {linkStatus === "copied" && <p className="text-[11px] text-gold" role="status">{c.copied}</p>}
        {linkStatus === "manual" && <input className="mt-1" type="text" aria-label={c.link} readOnly value={resumeUrl.href} onFocus={event => event.currentTarget.select()} />}
      </div>
    </dialog>, document.body,
  );
}
