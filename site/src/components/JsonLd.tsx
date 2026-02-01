export function JsonLd() {
  const schema = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'SoftwareApplication',
        name: 'Claude Trace',
        applicationCategory: 'DeveloperApplication',
        operatingSystem: 'macOS',
        description:
          'Real-time CPU and memory monitoring for Claude Code CLI. Native macOS menu bar app with instant visibility into every Claude process.',
        url: 'https://claude-trace.vercel.app',
        downloadUrl: 'https://github.com/joemccann/claude-trace',
        softwareVersion: '1.10.0',
        author: {
          '@type': 'Person',
          name: 'Joe McCann',
          url: 'https://github.com/joemccann',
        },
        offers: {
          '@type': 'Offer',
          price: '0',
          priceCurrency: 'USD',
        },
        aggregateRating: {
          '@type': 'AggregateRating',
          ratingValue: '5',
          ratingCount: '1',
        },
      },
      {
        '@type': 'WebSite',
        name: 'Claude Trace',
        url: 'https://claude-trace.vercel.app',
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
