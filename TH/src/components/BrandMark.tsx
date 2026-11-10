import { brandSymbolPaths } from '../lib/brand';

export function BrandMark({ className = '' }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 64 64"
      fill="none"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      data-brand-mark="astro-star"
    >
      {brandSymbolPaths.map((path, i) => {
        const color = path.tone === 'gold' ? 'rgb(var(--c-gold))' : 'currentColor';
        return (
          <path
            key={i}
            d={path.d}
            stroke={color}
            strokeWidth={path.width}
            fill={path.fill === 'none' ? 'none' : color}
            fillOpacity={path.fill === 'soft' ? 0.045 : 1}
          />
        );
      })}
    </svg>
  );
}
