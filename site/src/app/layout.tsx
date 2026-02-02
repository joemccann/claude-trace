import type { Metadata } from 'next'
import { GeistSans } from 'geist/font/sans'
import { GeistMono } from 'geist/font/mono'
import { JsonLd } from '@/components/JsonLd'
import './globals.css'

export const metadata: Metadata = {
  metadataBase: new URL('https://claude-trace.com'),
  alternates: {
    canonical: '/',
  },
  title: 'Claude Trace | Monitor Claude Code Performance',
  description: 'Your Claude Code is slow. Here\'s why. Real-time CPU and memory monitoring for Claude Code CLI. Native macOS menu bar app with instant visibility into every Claude process.',
  keywords: ['Claude Code', 'performance monitor', 'macOS', 'menu bar', 'CLI', 'CPU monitor', 'memory monitor', 'Anthropic', 'developer tools'],
  authors: [{ name: 'Joe McCann' }],
  creator: 'Joe McCann',
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://claude-trace.com',
    title: 'Claude Trace | Monitor Claude Code Performance',
    description: 'Your Claude Code is slow. Here\'s why. Real-time CPU and memory monitoring.',
    siteName: 'Claude Trace',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Claude Trace',
    description: 'Your Claude Code is slow. Here\'s why.',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className={`${GeistSans.variable} ${GeistMono.variable}`}>
      <body className="font-sans antialiased grain-overlay">
        <JsonLd />
        {children}
      </body>
    </html>
  )
}
