import { ImageResponse } from 'next/og'

export const runtime = 'edge'
export const size = { width: 32, height: 32 }
export const contentType = 'image/png'

export default function Icon() {
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
          borderRadius: '6px',
        }}
      >
        {/* Bar chart icon */}
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="#0a0a0a"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          {/* Three bars representing monitoring/trace */}
          <rect x="3" y="12" width="4" height="9" rx="1" fill="#0a0a0a" stroke="none" />
          <rect x="10" y="7" width="4" height="14" rx="1" fill="#0a0a0a" stroke="none" />
          <rect x="17" y="3" width="4" height="18" rx="1" fill="#0a0a0a" stroke="none" />
        </svg>
      </div>
    ),
    { ...size }
  )
}
