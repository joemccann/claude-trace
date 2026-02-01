import { ImageResponse } from 'next/og'

export const runtime = 'edge'
export const size = { width: 180, height: 180 }
export const contentType = 'image/png'

export default function AppleIcon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'linear-gradient(135deg, #22d3ee 0%, #0891b2 100%)',
          borderRadius: '36px',
        }}
      >
        {/* Bar chart icon - scaled up for Apple icon */}
        <svg
          width="110"
          height="110"
          viewBox="0 0 24 24"
          fill="none"
        >
          {/* Three bars representing monitoring/trace */}
          <rect x="3" y="12" width="4" height="9" rx="1" fill="#0a0a0a" />
          <rect x="10" y="7" width="4" height="14" rx="1" fill="#0a0a0a" />
          <rect x="17" y="3" width="4" height="18" rx="1" fill="#0a0a0a" />
        </svg>
      </div>
    ),
    { ...size }
  )
}
