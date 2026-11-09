import { useEffect, useState, type FormEvent } from 'react';
import { ArrowUpRight, Bookmark, Check, Pencil, Plus, Trash2 } from 'lucide-react';
import { PickerDialog } from './PickerDialog';
import { fillCopy } from '../lib/fortune';
import type { Copy } from '../lib/i18n';
import type { Memory } from '../types';

export function MemoryPanel({
  memories,
  t,
  compact = false,
  onAdd,
  onDelete,
  onViewAll,
  onEdit,
}: {
  memories: Memory[];
  t: Copy;
  compact?: boolean;
  onAdd: (content: string) => Promise<void>;
  onDelete: (id: string) => Promise<void>;
  onViewAll: () => void;
  onEdit?: (id: string, content: string) => Promise<void>;
}) {
  const [content, setContent] = useState('');
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');
  const [editing, setEditing] = useState<Memory | null>(null);
  async function saveEdit() {
    if (!editing || !onEdit || !editing.content.trim() || pending) return;
    setPending(true);
    setError('');
    try {
      await onEdit(editing.id, editing.content.trim());
      setEditing(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setPending(false);
    }
  }
  useEffect(() => setError(''), [t]);
  async function submit(event: FormEvent) {
    event.preventDefault();
    setError('');
    setPending(true);
    try {
      await onAdd(content.trim());
      setContent('');
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setPending(false);
    }
  }
  async function remove(id: string) {
    setPending(true);
    setError('');
    try {
      await onDelete(id);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setPending(false);
    }
  }
  return (
    <section
      className={`panel ${compact ? 'p-5' : 'enter mx-auto max-w-3xl p-6 sm:p-9'}`}
      aria-labelledby={compact ? 'memory-preview-title' : 'memory-title'}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-3">
          <span className="rounded-xl bg-surface p-2.5 text-gold">
            <Bookmark size={compact ? 17 : 21} />
          </span>
          <div>
            <h2
              id={compact ? 'memory-preview-title' : 'memory-title'}
              className={compact ? 'text-sm font-semibold' : 'text-xl font-semibold'}
            >
              {t.memoryTitle}
            </h2>
            <p className="mt-1 text-xs leading-5 text-muted">{t.memorySub}</p>
          </div>
        </div>
        {compact && (
          <button
            className="btn-quiet shrink-0 !px-1 !text-xs"
            onClick={onViewAll}
            aria-label={t.viewAll}
          >
            <ArrowUpRight size={16} />
          </button>
        )}
      </div>
      {!compact && <p className="mt-4 text-xs leading-6 text-muted">{t.m_privacy}</p>}
      {memories.length ? (
        <ul className="mt-5 space-y-3">
          {(compact ? memories.slice(-2) : memories).map((memory) => (
            <li key={memory.id} className="flex items-start gap-3 rounded-xl bg-canvas px-4 py-3">
              <Check size={14} className="mt-1 shrink-0 text-accent/60" />
              <div className="min-w-0 flex-1">
                <p className="whitespace-pre-wrap break-words text-sm leading-6">
                  {memory.content}
                </p>
                {!compact && (
                  <span className="mt-1 inline-block text-[10px] text-muted">
                    {fillCopy(t.m_memoryDate, {
                      date: new Intl.DateTimeFormat(t.dateLocale, { dateStyle: 'medium' }).format(
                        new Date(memory.created * 1000),
                      ),
                    })}
                  </span>
                )}
              </div>
              {!compact && (
                <>
                  {onEdit && (
                    <button
                      type="button"
                      className="btn-quiet shrink-0 !px-2"
                      aria-label={t.m_edit}
                      disabled={pending}
                      onClick={() => {
                        setEditing(memory);
                        setError('');
                      }}
                    >
                      <Pencil size={14} />
                    </button>
                  )}
                  <button
                    aria-label={t.delete}
                    className="btn-quiet -mr-2 shrink-0 !px-2 hover:!text-rose-300"
                    disabled={pending}
                    onClick={() => void remove(memory.id)}
                  >
                    <Trash2 size={14} />
                  </button>
                </>
              )}
            </li>
          ))}
        </ul>
      ) : (
        <div
          className={`${compact ? 'mt-4 border-t border-line pt-4' : 'my-8 rounded-xl border border-dashed border-line p-7 text-center'}`}
        >
          <p className="text-xs font-medium text-muted">{t.memoryEmpty}</p>
          <p className="mt-1.5 text-xs leading-6 text-muted">{t.memoryEmptyNote}</p>
        </div>
      )}
      {!compact && (
        <form
          onSubmit={submit}
          className="mt-7 border-t border-line pt-6"
          onInvalidCapture={(event) => {
            event.preventDefault();
            setError(t.formInvalid);
            event.currentTarget.querySelector<HTMLElement>('textarea:invalid')?.focus();
          }}
        >
          <label htmlFor="new-memory" className="sr-only">
            {t.memoryPlaceholder}
          </label>
          <textarea
            id="new-memory"
            className="field min-h-28 resize-y"
            maxLength={500}
            required
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder={t.memoryPlaceholder}
          />
          <div className="mt-2 flex items-center justify-between gap-3 text-[11px] text-muted">
            <span>{t.memoryLimit}</span>
            <span>{content.length}/500</span>
          </div>
          <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
            <span className="text-xs text-muted">
              {memories.length}/20 {t.memoryCount}
            </span>
            <button
              className="btn-primary"
              disabled={pending || !content.trim() || memories.length >= 20}
            >
              <Plus size={15} />
              {t.remember}
            </button>
          </div>
        </form>
      )}
      {error && (
        <p role="alert" className="mt-4 text-sm text-rose-300">
          {error}
        </p>
      )}
      {editing && (
        <PickerDialog
          title={t.m_edit}
          t={t}
          confirmLabel={pending ? t.loading : t.w_save}
          confirmDisabled={pending || !editing.content.trim()}
          onConfirm={() => void saveEdit()}
          onCancel={() => {
            if (!pending) {
              setEditing(null);
              setError('');
            }
          }}
        >
          <label className="label" htmlFor="edit-memory">
            {t.m_editText}
          </label>
          <textarea
            id="edit-memory"
            className="field min-h-32"
            value={editing.content}
            maxLength={500}
            onChange={(event) => setEditing({ ...editing, content: event.target.value })}
          />
          {error && (
            <p role="alert" className="mt-3 text-sm text-accent">
              {error}
            </p>
          )}
        </PickerDialog>
      )}
    </section>
  );
}
