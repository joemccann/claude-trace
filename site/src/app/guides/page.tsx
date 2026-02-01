import Link from 'next/link'
import type { Metadata } from 'next'
import { guides } from './data'

export const metadata: Metadata = {
  title: 'Claude Code Troubleshooting Guides',
  description: 'Learn how to debug and fix common Claude Code CLI issues including CPU spikes, memory leaks, orphan processes, and slow performance.',
  alternates: {
    canonical: '/guides',
  },
  openGraph: {
    title: 'Claude Code Troubleshooting Guides | Claude Trace',
    description: 'Fix Claude Code performance issues with these expert guides.',
    url: '/guides',
  },
}

export default function GuidesPage() {
  return (
    <main className="min-h-screen bg-bg-primary">
      {/* Header */}
      <header className="border-b border-zinc-800">
        <div className="max-w-4xl mx-auto px-6 py-4">
          <Link href="/" className="text-cyan-400 hover:text-cyan-300 text-sm">
            ← Back to Claude Trace
          </Link>
        </div>
      </header>

      {/* Hero */}
      <section className="py-16 px-6">
        <div className="max-w-4xl mx-auto text-center">
          <h1 className="text-4xl sm:text-5xl font-bold text-text-primary mb-4">
            Claude Code Troubleshooting Guides
          </h1>
          <p className="text-xl text-text-secondary max-w-2xl mx-auto">
            Expert guides for debugging and fixing common Claude Code CLI issues.
            From CPU spikes to memory leaks, we&apos;ve got you covered.
          </p>
        </div>
      </section>

      {/* Guides Grid */}
      <section className="pb-24 px-6">
        <div className="max-w-4xl mx-auto">
          <div className="grid gap-6">
            {guides.map((guide) => (
              <Link
                key={guide.slug}
                href={`/guides/${guide.slug}`}
                className="group block p-6 bg-zinc-900/50 border border-zinc-800 rounded-xl hover:border-zinc-700 hover:bg-zinc-900 transition-all"
              >
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 rounded-lg bg-cyan-400/10 text-cyan-400 flex items-center justify-center flex-shrink-0 group-hover:bg-cyan-400/20 transition-colors">
                    <span className="text-2xl">{guide.icon}</span>
                  </div>
                  <div>
                    <h2 className="text-xl font-semibold text-text-primary mb-2 group-hover:text-cyan-400 transition-colors">
                      {guide.title}
                    </h2>
                    <p className="text-text-secondary">{guide.description}</p>
                    <div className="mt-3 flex flex-wrap gap-2">
                      {guide.tags.map((tag) => (
                        <span
                          key={tag}
                          className="px-2 py-1 text-xs rounded-full bg-zinc-800 text-text-muted"
                        >
                          {tag}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-zinc-800 py-8 px-6">
        <div className="max-w-4xl mx-auto text-center text-text-muted text-sm">
          <p>
            Part of{' '}
            <Link href="/" className="text-cyan-400 hover:underline">
              Claude Trace
            </Link>{' '}
            — Real-time monitoring for Claude Code
          </p>
        </div>
      </footer>
    </main>
  )
}
