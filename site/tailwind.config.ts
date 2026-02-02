import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // Firecrawl-inspired dark mode palette
        'bg-base': '#0a0a0a',
        'bg-surface': '#171717',
        'bg-raised': '#1f1f1f',
        'bg-primary': '#0a0a0a',
        'bg-secondary': '#171717',
        'bg-elevated': '#1f1f1f',
        // Text
        'text-primary': '#f5f5f5',
        'text-secondary': '#a3a3a3',
        'text-muted': '#737373',
        // Borders (Firecrawl style)
        'border-faint': '#2a2a2a',
        'border-muted': '#333333',
        'border-loud': '#404040',
        // Claude brand accent
        'accent': '#d97757',
        'accent-hover': '#e08a6d',
        'accent-muted': 'rgba(217, 119, 87, 0.1)',
        // Status colors
        'success': '#5cd47f',
        'warning': '#f0c550',
        'error': '#f05545',
      },
      fontFamily: {
        sans: ['var(--font-geist-sans)', 'system-ui', 'sans-serif'],
        mono: ['var(--font-geist-mono)', 'monospace'],
      },
      borderRadius: {
        'none': '0px',
        'sm': '2px',
        'DEFAULT': '2px',
        'md': '4px',
        'lg': '4px',
      },
      animation: {
        'fade-in-up': 'fadeInUp 0.5s ease-out forwards',
        'fade-in': 'fadeIn 0.5s ease-out forwards',
      },
      keyframes: {
        fadeInUp: {
          '0%': { opacity: '0', transform: 'translateY(12px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
      },
    },
  },
  plugins: [],
}
export default config
