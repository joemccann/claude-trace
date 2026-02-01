import { Metadata } from 'next'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { guides } from '../data'

interface PageProps {
  params: Promise<{ slug: string }>
}

export async function generateStaticParams() {
  return guides.map((guide) => ({
    slug: guide.slug,
  }))
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params
  const guide = guides.find((g) => g.slug === slug)

  if (!guide) {
    return {
      title: 'Guide Not Found',
    }
  }

  return {
    title: guide.title,
    description: guide.description,
    keywords: guide.keywords,
    alternates: {
      canonical: `/guides/${slug}`,
    },
    openGraph: {
      title: `${guide.title} | Claude Trace`,
      description: guide.description,
      url: `/guides/${slug}`,
      type: 'article',
    },
  }
}

function GuideSchema({ guide }: { guide: typeof guides[0] }) {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'HowTo',
    name: guide.title,
    description: guide.description,
    step: [
      {
        '@type': 'HowToStep',
        name: 'Identify the Problem',
        text: guide.content.problem,
      },
      {
        '@type': 'HowToStep',
        name: 'Diagnose',
        text: guide.content.diagnosis,
      },
      {
        '@type': 'HowToStep',
        name: 'Apply the Solution',
        text: guide.content.solution,
      },
    ],
    tool: {
      '@type': 'SoftwareApplication',
      name: 'Claude Trace',
      url: 'https://claude-trace.com',
    },
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}

function BreadcrumbSchema({ guide }: { guide: typeof guides[0] }) {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      {
        '@type': 'ListItem',
        position: 1,
        name: 'Claude Trace',
        item: 'https://claude-trace.com',
      },
      {
        '@type': 'ListItem',
        position: 2,
        name: 'Guides',
        item: 'https://claude-trace.com/guides',
      },
      {
        '@type': 'ListItem',
        position: 3,
        name: guide.title,
        item: `https://claude-trace.com/guides/${guide.slug}`,
      },
    ],
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}

export default async function GuidePage({ params }: PageProps) {
  const { slug } = await params
  const guide = guides.find((g) => g.slug === slug)

  if (!guide) {
    notFound()
  }

  return (
    <>
      <GuideSchema guide={guide} />
      <BreadcrumbSchema guide={guide} />

      <main className="min-h-screen bg-bg-primary">
        {/* Header */}
        <header className="border-b border-zinc-800">
          <div className="max-w-3xl mx-auto px-6 py-4">
            <nav className="flex items-center gap-2 text-sm text-text-muted">
              <Link href="/" className="hover:text-cyan-400">Claude Trace</Link>
              <span>/</span>
              <Link href="/guides" className="hover:text-cyan-400">Guides</Link>
              <span>/</span>
              <span className="text-text-secondary truncate">{guide.title}</span>
            </nav>
          </div>
        </header>

        {/* Article */}
        <article className="py-12 px-6">
          <div className="max-w-3xl mx-auto">
            {/* Title */}
            <div className="mb-8">
              <span className="text-4xl mb-4 block">{guide.icon}</span>
              <h1 className="text-3xl sm:text-4xl font-bold text-text-primary mb-4">
                {guide.title}
              </h1>
              <p className="text-xl text-text-secondary">
                {guide.description}
              </p>
              <div className="mt-4 flex flex-wrap gap-2">
                {guide.tags.map((tag) => (
                  <span
                    key={tag}
                    className="px-3 py-1 text-sm rounded-full bg-cyan-400/10 text-cyan-400"
                  >
                    {tag}
                  </span>
                ))}
              </div>
            </div>

            {/* Quick Command */}
            {guide.content.cliCommand && (
              <div className="mb-8 p-4 bg-zinc-900 border border-zinc-800 rounded-lg">
                <div className="text-sm text-text-muted mb-2">Quick Command</div>
                <code className="text-cyan-400 font-mono text-sm">
                  $ {guide.content.cliCommand}
                </code>
              </div>
            )}

            {/* Content */}
            <div className="prose prose-invert prose-zinc max-w-none">
              {/* Problem */}
              <section className="mb-10">
                <h2 className="text-2xl font-bold text-text-primary mb-4 flex items-center gap-2">
                  <span className="w-8 h-8 rounded-lg bg-red-400/10 text-red-400 flex items-center justify-center text-sm">!</span>
                  The Problem
                </h2>
                <p className="text-text-secondary text-lg leading-relaxed">
                  {guide.content.problem}
                </p>
              </section>

              {/* Causes */}
              <section className="mb-10">
                <h2 className="text-2xl font-bold text-text-primary mb-4 flex items-center gap-2">
                  <span className="w-8 h-8 rounded-lg bg-yellow-400/10 text-yellow-400 flex items-center justify-center text-sm">?</span>
                  Common Causes
                </h2>
                <ul className="space-y-2">
                  {guide.content.causes.map((cause, i) => (
                    <li key={i} className="flex items-start gap-3 text-text-secondary">
                      <span className="text-cyan-400 mt-1">•</span>
                      {cause}
                    </li>
                  ))}
                </ul>
              </section>

              {/* Diagnosis */}
              <section className="mb-10">
                <h2 className="text-2xl font-bold text-text-primary mb-4 flex items-center gap-2">
                  <span className="w-8 h-8 rounded-lg bg-blue-400/10 text-blue-400 flex items-center justify-center text-sm">🔍</span>
                  How to Diagnose
                </h2>
                <div className="bg-zinc-900 border border-zinc-800 rounded-lg p-6 overflow-x-auto">
                  <pre className="text-sm text-text-secondary whitespace-pre-wrap font-mono">
                    {guide.content.diagnosis}
                  </pre>
                </div>
              </section>

              {/* Solution */}
              <section className="mb-10">
                <h2 className="text-2xl font-bold text-text-primary mb-4 flex items-center gap-2">
                  <span className="w-8 h-8 rounded-lg bg-green-400/10 text-green-400 flex items-center justify-center text-sm">✓</span>
                  Solution
                </h2>
                <div className="bg-zinc-900 border border-zinc-800 rounded-lg p-6 overflow-x-auto">
                  <pre className="text-sm text-text-secondary whitespace-pre-wrap font-mono">
                    {guide.content.solution}
                  </pre>
                </div>
              </section>

              {/* Prevention */}
              <section className="mb-10">
                <h2 className="text-2xl font-bold text-text-primary mb-4 flex items-center gap-2">
                  <span className="w-8 h-8 rounded-lg bg-purple-400/10 text-purple-400 flex items-center justify-center text-sm">🛡</span>
                  Prevention
                </h2>
                <div className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-6">
                  <pre className="text-sm text-text-secondary whitespace-pre-wrap font-mono">
                    {guide.content.prevention}
                  </pre>
                </div>
              </section>
            </div>

            {/* CTA */}
            <div className="mt-12 p-6 bg-gradient-to-r from-cyan-400/10 to-blue-400/10 border border-cyan-400/20 rounded-xl text-center">
              <h3 className="text-xl font-bold text-text-primary mb-2">
                Monitor Claude Code in Real-Time
              </h3>
              <p className="text-text-secondary mb-4">
                Get Claude Trace for instant visibility into every Claude process.
              </p>
              <Link
                href="/"
                className="inline-flex items-center gap-2 px-6 py-3 bg-cyan-400 text-zinc-900 font-semibold rounded-lg hover:bg-cyan-300 transition-colors"
              >
                Get Claude Trace
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 8l4 4m0 0l-4 4m4-4H3" />
                </svg>
              </Link>
            </div>

            {/* Related Guides */}
            <div className="mt-12">
              <h3 className="text-lg font-semibold text-text-primary mb-4">
                Related Guides
              </h3>
              <div className="grid gap-4 sm:grid-cols-2">
                {guides
                  .filter((g) => g.slug !== guide.slug)
                  .slice(0, 4)
                  .map((relatedGuide) => (
                    <Link
                      key={relatedGuide.slug}
                      href={`/guides/${relatedGuide.slug}`}
                      className="block p-4 bg-zinc-900/50 border border-zinc-800 rounded-lg hover:border-zinc-700 transition-colors"
                    >
                      <span className="text-lg mr-2">{relatedGuide.icon}</span>
                      <span className="text-text-secondary hover:text-cyan-400">
                        {relatedGuide.title}
                      </span>
                    </Link>
                  ))}
              </div>
            </div>
          </div>
        </article>

        {/* Footer */}
        <footer className="border-t border-zinc-800 py-8 px-6">
          <div className="max-w-3xl mx-auto text-center text-text-muted text-sm">
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
    </>
  )
}
