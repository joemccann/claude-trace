export function JsonLd() {
  const schema = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'Organization',
        '@id': 'https://claude-trace.com/#organization',
        name: 'Claude Trace',
        url: 'https://claude-trace.com',
        logo: {
          '@type': 'ImageObject',
          url: 'https://claude-trace.com/icon',
          width: 32,
          height: 32,
        },
        sameAs: ['https://github.com/joemccann/claude-trace'],
        founder: {
          '@type': 'Person',
          name: 'Joe McCann',
          url: 'https://github.com/joemccann',
        },
      },
      {
        '@type': 'WebSite',
        '@id': 'https://claude-trace.com/#website',
        name: 'Claude Trace',
        url: 'https://claude-trace.com',
        description: 'Real-time CPU and memory monitoring for Claude Code CLI',
        publisher: {
          '@id': 'https://claude-trace.com/#organization',
        },
      },
      {
        '@type': 'SoftwareApplication',
        '@id': 'https://claude-trace.com/#software',
        name: 'Claude Trace',
        applicationCategory: 'DeveloperApplication',
        operatingSystem: 'macOS 14.0+',
        description:
          'Real-time CPU and memory monitoring for Claude Code CLI. Native macOS menu bar app with instant visibility into every Claude process.',
        url: 'https://claude-trace.com',
        downloadUrl: 'https://github.com/joemccann/claude-trace',
        softwareVersion: '1.13.3',
        softwareRequirements: 'macOS 14.0+ and Xcode 15.0+',
        author: {
          '@id': 'https://claude-trace.com/#organization',
        },
        offers: {
          '@type': 'Offer',
          price: '0',
          priceCurrency: 'USD',
          availability: 'https://schema.org/InStock',
        },
        featureList: [
          'Live CPU & Memory monitoring',
          'Project name tracking per Claude session',
          'Native macOS notifications with custom thresholds',
          'One-click process termination',
          'Orphan process detection and cleanup',
          'Launch at login support',
          'CLI with JSON output for scripting',
          'Watch mode with live updates',
        ],
        screenshot: [
          {
            '@type': 'ImageObject',
            url: 'https://claude-trace.com/menubar-dropdown.png',
            caption:
              'Claude Trace Menu Bar showing real-time CPU and memory monitoring',
          },
          {
            '@type': 'ImageObject',
            url: 'https://claude-trace.com/cli-output.png',
            caption: 'Claude Trace CLI output showing process monitoring',
          },
        ],
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
