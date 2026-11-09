export default {
  content: ['./src/**/*.{ts,tsx}'],
  corePlugins: { preflight: false },
  theme: {
    extend: {
      keyframes: {
        'report-visual-breathe': {
          '0%, 100%': { opacity: '.88' },
          '50%': { opacity: '1' },
        },
      },
      animation: {
        'report-visual-breathe': 'report-visual-breathe 1.4s ease-in-out infinite',
      },
      colors: {
        night: '#130c24',
        plum: '#27173d',
        gold: '#e4bc78',
        cream: '#fff5df',
        lavender: '#b4a8c6',
      },
    },
  },
};
