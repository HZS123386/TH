/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      screens: {
        brandCompact: { raw: '(max-width: 360px)' },
        languageCompact: { raw: '(max-height: 820px)' },
        languageTight: { raw: '(max-height: 680px)' },
        languageWide: { raw: '(max-height: 500px)' },
        languageTiny: { raw: '(max-height: 340px)' },
      },
      colors: {
        accent: 'rgb(var(--c-accent) / <alpha-value>)',
        primary: 'rgb(var(--c-primary) / <alpha-value>)',
        'on-primary': 'rgb(var(--c-on-primary) / <alpha-value>)',
        surface: 'rgb(var(--c-surface) / <alpha-value>)',
        canvas: 'rgb(var(--c-canvas) / <alpha-value>)',
        panel: 'rgb(var(--c-panel) / <alpha-value>)',
        ink: 'rgb(var(--c-ink) / <alpha-value>)',
        muted: 'rgb(var(--c-muted) / <alpha-value>)',
        line: 'rgb(var(--c-line) / <alpha-value>)',
        gold: 'rgb(var(--c-gold) / <alpha-value>)',
        night: 'rgb(var(--c-night) / <alpha-value>)',
      },
      fontFamily: {
        sans: [
          '"Noto Sans Thai"',
          '"Leelawadee UI"',
          '"Microsoft YaHei UI"',
          '"Microsoft YaHei"',
          'sans-serif',
        ],
        display: ['Georgia', '"Times New Roman"', 'serif'],
      },
      boxShadow: {
        soft: '0 12px 36px -24px rgb(0 0 0 / .7)',
      },
    },
  },
  plugins: [],
};
