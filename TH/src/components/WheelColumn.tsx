import { useId, useLayoutEffect, useRef } from 'react';

export interface WheelOption {
  value: string;
  label: string;
}
const ROW_HEIGHT = 44;

export function WheelColumn({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: WheelOption[];
  value: string;
  onChange: (value: string) => void;
}) {
  const id = useId();
  const scrollRef = useRef<HTMLDivElement>(null);
  const drag = useRef<{ y: number; top: number; moved: boolean; option: number | null } | null>(
    null,
  );
  const ignoreClick = useRef(false);
  const index = Math.max(
    0,
    options.findIndex((option) => option.value === value),
  );

  useLayoutEffect(() => {
    const element = scrollRef.current;
    // A scroll updates the value too: don't interrupt touch momentum at each row.
    if (element && Math.abs(element.scrollTop - index * ROW_HEIGHT) > ROW_HEIGHT / 2) {
      element.scrollTop = index * ROW_HEIGHT;
    }
  }, [index, options.length]);

  function select(nextIndex: number) {
    const bounded = Math.max(0, Math.min(options.length - 1, nextIndex));
    if (!options[bounded]) return;
    scrollRef.current!.scrollTop = bounded * ROW_HEIGHT;
    onChange(options[bounded].value);
  }

  return (
    <div className="min-w-0 flex-1">
      <p className="mb-3 truncate text-center text-xs text-muted" id={`${id}-label`}>
        {label}
      </p>
      <div
        ref={scrollRef}
        role="listbox"
        tabIndex={0}
        aria-labelledby={`${id}-label`}
        aria-activedescendant={`${id}-${index}`}
        className="wheel-column relative h-[220px] cursor-grab touch-pan-y overflow-y-auto overscroll-contain rounded-xl py-[88px] outline-none focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-accent/40 active:cursor-grabbing"
        onScroll={(event) => {
          const nextIndex = Math.max(
            0,
            Math.min(options.length - 1, Math.round(event.currentTarget.scrollTop / ROW_HEIGHT)),
          );
          if (options[nextIndex]?.value !== value) onChange(options[nextIndex].value);
        }}
        onKeyDown={(event) => {
          const next = {
            ArrowUp: index - 1,
            ArrowDown: index + 1,
            PageUp: index - 10,
            PageDown: index + 10,
            Home: 0,
            End: options.length - 1,
          }[event.key];
          if (next !== undefined) {
            event.preventDefault();
            select(next);
          }
        }}
        onPointerDown={(event) => {
          ignoreClick.current = false;
          if (event.pointerType !== 'mouse' || event.button !== 0) return;
          event.preventDefault();
          event.currentTarget.focus();
          event.currentTarget.setPointerCapture(event.pointerId);
          event.currentTarget.style.scrollSnapType = 'none';
          const option = (event.target as HTMLElement).closest<HTMLElement>('[data-wheel-index]');
          drag.current = {
            y: event.clientY,
            top: event.currentTarget.scrollTop,
            moved: false,
            option: option ? Number(option.dataset.wheelIndex) : null,
          };
        }}
        onPointerMove={(event) => {
          if (!drag.current) return;
          const delta = drag.current.y - event.clientY;
          if (Math.abs(delta) > 4) drag.current.moved = true;
          event.currentTarget.scrollTop = drag.current.top + delta;
        }}
        onPointerUp={(event) => {
          if (!drag.current) return;
          const next =
            !drag.current.moved && drag.current.option !== null
              ? drag.current.option
              : Math.round(event.currentTarget.scrollTop / ROW_HEIGHT);
          ignoreClick.current = true;
          drag.current = null;
          event.currentTarget.style.scrollSnapType = '';
          if (event.currentTarget.hasPointerCapture(event.pointerId)) {
            event.currentTarget.releasePointerCapture(event.pointerId);
          }
          select(next);
        }}
        onPointerCancel={(event) => {
          drag.current = null;
          event.currentTarget.style.scrollSnapType = '';
        }}
      >
        {options.map((option, optionIndex) => (
          <div
            key={option.value}
            id={`${id}-${optionIndex}`}
            role="option"
            data-wheel-index={optionIndex}
            aria-selected={optionIndex === index}
            className={`flex h-11 select-none snap-center items-center justify-center px-1 text-center text-sm leading-tight transition-colors sm:text-base ${optionIndex === index ? 'font-semibold text-accent' : 'text-muted/70'}`}
            onClick={() => {
              if (ignoreClick.current) {
                ignoreClick.current = false;
                return;
              }
              select(optionIndex);
            }}
          >
            {option.label}
          </div>
        ))}
      </div>
    </div>
  );
}
