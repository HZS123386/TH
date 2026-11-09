import { useEffect, useId, useRef, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { Check, X } from 'lucide-react';
import type { Copy } from '../lib/i18n';

export function PickerDialog({
  title,
  t,
  children,
  onConfirm,
  onCancel,
  confirmLabel,
  confirmDisabled = false,
}: {
  title: string;
  t: Copy;
  children: ReactNode;
  onConfirm: () => void;
  onCancel: () => void;
  confirmLabel?: string;
  confirmDisabled?: boolean;
}) {
  const id = useId();
  const panelRef = useRef<HTMLDivElement>(null);
  const cancelRef = useRef(onCancel);
  cancelRef.current = onCancel;
  useEffect(() => {
    const previousFocus = document.activeElement as HTMLElement | null;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    panelRef.current?.focus();
    function keyboard(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        event.preventDefault();
        cancelRef.current();
      }
      if (event.key !== 'Tab') return;
      const controls = panelRef.current?.querySelectorAll<HTMLElement>(
        'button:not(:disabled),input:not(:disabled),textarea:not(:disabled),select:not(:disabled),[tabindex="0"]',
      );
      if (!controls?.length) return;
      const first = controls[0],
        last = controls[controls.length - 1];
      if (
        event.shiftKey &&
        (document.activeElement === first || document.activeElement === panelRef.current)
      ) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
    document.addEventListener('keydown', keyboard);
    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener('keydown', keyboard);
      previousFocus?.focus();
    };
  }, []);
  return createPortal(
    <div
      className="fixed inset-0 z-[80] flex items-end justify-center overflow-y-auto bg-[#453b2e]/35 p-3 backdrop-blur-sm sm:items-center sm:p-6"
      onClick={(event) => {
        if (event.target === event.currentTarget) onCancel();
      }}
    >
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={id}
        tabIndex={-1}
        className="enter my-auto max-h-[calc(100dvh-24px)] w-full max-w-[430px] overflow-y-auto rounded-[24px] border border-[#d8c29e] bg-panel p-5 shadow-2xl outline-none sm:p-6"
      >
        <div className="mb-5 flex items-center justify-between gap-3">
          <h3 id={id} className="text-lg font-semibold">
            {title}
          </h3>
          <button
            type="button"
            className="btn-quiet !rounded-full !p-2"
            aria-label={t.pickerCancel}
            onClick={onCancel}
          >
            <X size={20} />
          </button>
        </div>
        {children}
        <button
          type="button"
          className="btn-primary mt-6 w-full !rounded-2xl !py-3.5"
          onClick={onConfirm}
          disabled={confirmDisabled}
        >
          <Check size={18} />
          {confirmLabel || t.pickerDone}
        </button>
      </div>
    </div>,
    document.body,
  );
}

export function WheelGroup({ children }: { children: ReactNode }) {
  return (
    <div className="relative">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-x-0 top-[116px] h-11 rounded-xl border border-accent/60 bg-gradient-to-r from-[#dec9a8]/50 to-[#d9b49f]/40 shadow-sm"
      />
      <div className="relative flex gap-1 sm:gap-3">{children}</div>
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-x-0 top-7 h-16 bg-gradient-to-b from-panel to-transparent"
      />
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-x-0 bottom-0 h-16 bg-gradient-to-t from-panel to-transparent"
      />
    </div>
  );
}
