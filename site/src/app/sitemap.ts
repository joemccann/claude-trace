import { MetadataRoute } from 'next'

// Guide slugs for programmatic pages
const guideSlugs = [
  'claude-code-high-cpu',
  'claude-code-memory-leak',
  'claude-code-orphan-processes',
  'claude-code-slow-response',
  'claude-code-multiple-sessions',
  'claude-code-outdated-version',
  'kill-all-claude-processes',
  'claude-code-debug-flamegraph',
]

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = 'https://claude-trace.com'

  // Main pages
  const mainPages: MetadataRoute.Sitemap = [
    {
      url: baseUrl,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 1,
    },
    {
      url: `${baseUrl}/guides`,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 0.9,
    },
  ]

  // Guide pages (programmatic SEO)
  const guidePages: MetadataRoute.Sitemap = guideSlugs.map((slug) => ({
    url: `${baseUrl}/guides/${slug}`,
    lastModified: new Date(),
    changeFrequency: 'monthly' as const,
    priority: 0.8,
  }))

  return [...mainPages, ...guidePages]
}
