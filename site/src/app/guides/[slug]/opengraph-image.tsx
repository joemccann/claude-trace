import { ImageResponse } from 'next/og'
import { guides } from '../data'

export const runtime = 'edge'
export const alt = 'Claude Trace Guide'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const guide = guides.find((g) => g.slug === slug)

  if (!guide) {
    return new ImageResponse(
      (
        <div
          style={{
            height: '100%',
            width: '100%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: '#0a0a0a',
            color: '#fafafa',
            fontSize: 48,
          }}
        >
          Guide Not Found
        </div>
      ),
      { ...size }
    )
  }

  return new ImageResponse(
    (
      <div
        style={{
          height: '100%',
          width: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-start',
          justifyContent: 'center',
          backgroundColor: '#0a0a0a',
          fontFamily: 'system-ui, sans-serif',
          padding: '60px 80px',
          position: 'relative',
        }}
      >
        {/* Background gradient */}
        <div
          style={{
            position: 'absolute',
            top: '-20%',
            right: '-10%',
            width: '600px',
            height: '600px',
            borderRadius: '50%',
            background: 'radial-gradient(circle, rgba(34, 211, 238, 0.1) 0%, transparent 70%)',
          }}
        />

        {/* Guide badge */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            marginBottom: '24px',
          }}
        >
          <span
            style={{
              fontSize: '14px',
              color: '#22d3ee',
              textTransform: 'uppercase',
              letterSpacing: '2px',
              fontWeight: 600,
            }}
          >
            Troubleshooting Guide
          </span>
        </div>

        {/* Icon */}
        <div
          style={{
            fontSize: '64px',
            marginBottom: '24px',
          }}
        >
          {guide.icon}
        </div>

        {/* Title */}
        <h1
          style={{
            fontSize: '52px',
            fontWeight: 700,
            color: '#fafafa',
            lineHeight: 1.2,
            marginBottom: '24px',
            maxWidth: '900px',
          }}
        >
          {guide.title}
        </h1>

        {/* Description */}
        <p
          style={{
            fontSize: '24px',
            color: '#a1a1aa',
            lineHeight: 1.5,
            maxWidth: '800px',
          }}
        >
          {guide.description}
        </p>

        {/* Tags */}
        <div
          style={{
            display: 'flex',
            gap: '12px',
            marginTop: '32px',
          }}
        >
          {guide.tags.map((tag) => (
            <span
              key={tag}
              style={{
                padding: '8px 16px',
                backgroundColor: 'rgba(34, 211, 238, 0.1)',
                color: '#22d3ee',
                borderRadius: '20px',
                fontSize: '16px',
              }}
            >
              {tag}
            </span>
          ))}
        </div>

        {/* Footer */}
        <div
          style={{
            position: 'absolute',
            bottom: '40px',
            left: '80px',
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
          }}
        >
          <span
            style={{
              fontSize: '24px',
              fontWeight: 600,
              color: '#fafafa',
            }}
          >
            Claude Trace
          </span>
          <span style={{ color: '#71717a' }}>•</span>
          <span style={{ color: '#71717a', fontSize: '18px' }}>
            claude-trace.com
          </span>
        </div>
      </div>
    ),
    { ...size }
  )
}
