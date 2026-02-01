import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "Claude Trace - Monitor Claude Code Performance";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          height: "100%",
          width: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: "#0a0a0a",
          fontFamily: "system-ui, sans-serif",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Background gradient glow */}
        <div
          style={{
            position: "absolute",
            top: "-50%",
            left: "50%",
            transform: "translateX(-50%)",
            width: "800px",
            height: "800px",
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(34, 211, 238, 0.15) 0%, transparent 70%)",
          }}
        />

        {/* Terminal window mockup */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            width: "900px",
            backgroundColor: "#141414",
            borderRadius: "12px",
            border: "1px solid #2a2a2a",
            overflow: "hidden",
            boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.5)",
          }}
        >
          {/* Terminal header */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              padding: "12px 16px",
              backgroundColor: "#1a1a1a",
              borderBottom: "1px solid #2a2a2a",
            }}
          >
            {/* Window controls */}
            <div style={{ display: "flex", gap: "8px" }}>
              <div
                style={{
                  width: "12px",
                  height: "12px",
                  borderRadius: "50%",
                  backgroundColor: "#ff5f57",
                }}
              />
              <div
                style={{
                  width: "12px",
                  height: "12px",
                  borderRadius: "50%",
                  backgroundColor: "#ffbd2e",
                }}
              />
              <div
                style={{
                  width: "12px",
                  height: "12px",
                  borderRadius: "50%",
                  backgroundColor: "#28c840",
                }}
              />
            </div>
            <div
              style={{
                flex: 1,
                textAlign: "center",
                color: "#71717a",
                fontSize: "14px",
              }}
            >
              claude-trace
            </div>
          </div>

          {/* Terminal content */}
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              padding: "24px",
              gap: "8px",
            }}
          >
            {/* Command line */}
            <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
              <span style={{ color: "#22d3ee", fontSize: "16px" }}>$</span>
              <span style={{ color: "#fafafa", fontSize: "16px" }}>
                claude-trace -v
              </span>
            </div>

            {/* Header row */}
            <div
              style={{
                display: "flex",
                color: "#71717a",
                fontSize: "13px",
                marginTop: "16px",
                fontFamily: "monospace",
              }}
            >
              <span style={{ width: "70px" }}>PID</span>
              <span style={{ width: "80px" }}>CPU%</span>
              <span style={{ width: "80px" }}>MEM%</span>
              <span style={{ width: "100px" }}>RSS</span>
              <span style={{ width: "80px" }}>STATE</span>
              <span style={{ flex: 1 }}>PROJECT</span>
            </div>

            {/* Process rows */}
            {[
              { pid: "12847", cpu: "78.2", mem: "3.4", rss: "412M", state: "R+", project: "my-app" },
              { pid: "12892", cpu: "45.1", mem: "2.1", rss: "256M", state: "S+", project: "api-server" },
              { pid: "13201", cpu: "12.8", mem: "1.8", rss: "218M", state: "S", project: "docs" },
            ].map((proc) => (
              <div
                key={proc.pid}
                style={{
                  display: "flex",
                  color: "#fafafa",
                  fontSize: "14px",
                  fontFamily: "monospace",
                }}
              >
                <span style={{ width: "70px", color: "#a1a1aa" }}>{proc.pid}</span>
                <span
                  style={{
                    width: "80px",
                    color:
                      parseFloat(proc.cpu) >= 80
                        ? "#f87171"
                        : parseFloat(proc.cpu) >= 50
                        ? "#fbbf24"
                        : "#22d3ee",
                  }}
                >
                  {proc.cpu}
                </span>
                <span style={{ width: "80px", color: "#a1a1aa" }}>{proc.mem}</span>
                <span style={{ width: "100px", color: "#a1a1aa" }}>{proc.rss}</span>
                <span style={{ width: "80px", color: "#22d3ee" }}>{proc.state}</span>
                <span style={{ flex: 1, color: "#22d3ee" }}>{proc.project}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Title and tagline */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            marginTop: "40px",
          }}
        >
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: "12px",
            }}
          >
            <span
              style={{
                fontSize: "48px",
                fontWeight: "700",
                color: "#fafafa",
              }}
            >
              Claude Trace
            </span>
          </div>
          <span
            style={{
              fontSize: "22px",
              color: "#71717a",
              marginTop: "8px",
            }}
          >
            Your Claude Code is slow. Here&apos;s why.
          </span>
        </div>
      </div>
    ),
    { ...size }
  );
}
