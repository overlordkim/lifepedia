/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        wiki: {
          bg: '#FFFFFF',
          'bg-secondary': '#F8F8F8',
          text: '#000000',
          secondary: '#666666',
          tertiary: '#999999',
          blue: '#0645AD',
          red: '#BA0000',
          border: '#CCCCCC',
          divider: '#E0E0E0',
          'heart-active': '#ED4956',
          'bookmark-active': '#F5C518',
        }
      },
      fontFamily: {
        serif: ['Georgia', 'Baskerville', '"Times New Roman"', 'serif'],
        sans: ['-apple-system', 'BlinkMacSystemFont', '"Segoe UI"', 'Roboto', '"Helvetica Neue"', 'Arial', 'sans-serif'],
      },
      fontSize: {
        'wiki-title': ['2rem', { lineHeight: '1.25', fontWeight: '700' }],
        'wiki-section': ['1.25rem', { lineHeight: '1.4', fontWeight: '700' }],
        'wiki-card-title': ['1.375rem', { lineHeight: '1.3', fontWeight: '600' }],
        'wiki-body': ['1rem', { lineHeight: '1.75' }],
        'wiki-excerpt': ['0.9375rem', { lineHeight: '1.6' }],
        'wiki-meta': ['0.8125rem', { lineHeight: '1.4' }],
        'wiki-small': ['0.75rem', { lineHeight: '1.4' }],
      }
    },
  },
  plugins: [],
}
