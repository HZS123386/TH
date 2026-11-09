/** A woven diamond repeat inspired by Thai textiles; no religious imagery. */
export function ThaiPattern({ className = '' }: { className?: string }) {
  return (
    <svg viewBox="0 0 340 180" fill="none" className={className} aria-hidden="true">
      <defs>
        <pattern id="thai-weave" width="60" height="60" patternUnits="userSpaceOnUse">
          <path d="m30 3 27 27-27 27L3 30 30 3Z" stroke="currentColor" strokeWidth=".7" />
          <path d="m30 12 18 18-18 18-18-18 18-18Z" stroke="currentColor" strokeWidth=".6" />
          <path d="m30 22 8 8-8 8-8-8 8-8Z" fill="currentColor" />
          <path d="M0 0h8v8H0zM52 52h8v8h-8z" fill="currentColor" fillOpacity=".5" />
        </pattern>
      </defs>
      <rect width="340" height="180" fill="url(#thai-weave)" />
    </svg>
  );
}
