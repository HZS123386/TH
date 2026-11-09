import type { Language } from '../types';

export function LanguageFlag({
  language,
  className = '',
}: {
  language: Language;
  className?: string;
}) {
  return (
    <span
      className={`inline-flex shrink-0 overflow-hidden rounded-full ring-1 ring-white/15 ${className}`}
      aria-hidden="true"
    >
      <svg viewBox="0 0 60 40" preserveAspectRatio="xMidYMid slice" className="h-full w-full">
        {language === 'zh' && (
          <>
            <path fill="#db343b" d="M0 0h60v40H0z" />
            <path
              fill="#ffe16b"
              d="m13 6 1.9 5.9h6.2l-5 3.6 1.9 5.9-5-3.6-5 3.6 1.9-5.9-5-3.6h6.2z"
            />
            {[
              [24, 5],
              [28, 11],
              [28, 19],
              [23, 24],
            ].map(([x, y]) => (
              <path
                key={y}
                transform={`translate(${x} ${y}) scale(.32)`}
                fill="#ffe16b"
                d="m0-5 1.2 3.5h3.7l-3 2.2L3 4.2 0 2-3 4.2l1.1-3.5-3-2.2h3.7Z"
              />
            ))}
          </>
        )}
        {language === 'th' && (
          <>
            <path fill="#b92d41" d="M0 0h60v40H0z" />
            <path fill="#faf6ee" d="M0 7h60v26H0z" />
            <path fill="#29376b" d="M0 13h60v14H0z" />
          </>
        )}
        {language === 'vi' && (
          <>
            <path fill="#da3039" d="M0 0h60v40H0z" />
            <path fill="#ffe36c" d="m30 7 3.1 9.4H43L35 22l3 9.4-8-5.8-8 5.8 3-9.4-8-5.6h9.9z" />
          </>
        )}
        {language === 'en' && (
          <>
            <path fill="#fff6f3" d="M0 0h60v40H0z" />
            {Array.from({ length: 7 }, (_, i) => (
              <path key={i} fill="#c44154" d={`M0 ${(i * 80) / 13}h60v${40 / 13}H0z`} />
            ))}
            <path fill="#314577" d="M0 0h25v21.6H0z" />
            {Array.from({ length: 9 }, (_, row) =>
              Array.from({ length: row % 2 ? 5 : 6 }, (_, col) => (
                <circle
                  key={`${row}-${col}`}
                  cx={2.2 + col * 4.1 + (row % 2 ? 2 : 0)}
                  cy={2 + row * 2.18}
                  r=".65"
                  fill="white"
                />
              )),
            )}
          </>
        )}
      </svg>
    </span>
  );
}
