'use client'

import { useState, useEffect, useCallback } from 'react'
import Image from 'next/image'

interface CarouselSlide {
  src: string
  alt: string
  title: string
  description: string
}

const slides: CarouselSlide[] = [
  {
    src: '/menubar-dropdown.png',
    alt: 'Claude Trace menu bar dropdown showing process list with CPU and memory stats',
    title: 'See All Sessions at a Glance',
    description: 'A native macOS app that lives in your menu bar. Always watching, never in the way.',
  },
  {
    src: '/settings-panel.png',
    alt: 'Claude Trace settings panel showing threshold configuration',
    title: 'Configure Thresholds',
    description: 'Set thresholds for CPU and memory. Get alerted when something goes wrong—before your laptop becomes a space heater.',
  },
  {
    src: '/notification.png',
    alt: 'macOS notification showing CPU threshold exceeded',
    title: 'Notifications That Matter',
    description: 'Know immediately when Claude goes rogue. Claude Trace watches in the background and alerts you when thresholds are exceeded.',
  },
  {
    src: '/detail-window.png',
    alt: 'Claude Trace process detail window showing expanded info',
    title: 'Deep Dive Into Any Session',
    description: 'Double-click any process to open a detailed view with full diagnostics, file descriptors, and thread info.',
  },
  {
    src: '/cli-output.png',
    alt: 'Claude Trace CLI output showing process table',
    title: 'Powerful CLI',
    description: 'Full command-line interface for scripting, automation, and quick terminal checks.',
  },
]

export function ImageCarousel() {
  const [currentIndex, setCurrentIndex] = useState(0)
  const [isAutoPlaying, setIsAutoPlaying] = useState(true)

  const goToSlide = useCallback((index: number) => {
    setCurrentIndex(index)
    setIsAutoPlaying(false)
  }, [])

  const nextSlide = useCallback(() => {
    setCurrentIndex((prev) => (prev + 1) % slides.length)
  }, [])

  const prevSlide = useCallback(() => {
    setCurrentIndex((prev) => (prev - 1 + slides.length) % slides.length)
  }, [])

  // Auto-advance slides
  useEffect(() => {
    if (!isAutoPlaying) return

    const interval = setInterval(() => {
      nextSlide()
    }, 5000)

    return () => clearInterval(interval)
  }, [isAutoPlaying, nextSlide])

  const currentSlide = slides[currentIndex]

  return (
    <div className="w-full">
      {/* Image Container */}
      <div className="relative border border-border-faint overflow-hidden">
        {/* Navigation Arrows */}
        <button
          onClick={prevSlide}
          className="absolute left-3 top-1/2 -translate-y-1/2 z-20 w-8 h-8 flex items-center justify-center bg-bg-base/80 border border-border-faint hover:border-accent hover:text-accent transition-colors"
          aria-label="Previous slide"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={1.5}>
            <path strokeLinecap="square" strokeLinejoin="miter" d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <button
          onClick={nextSlide}
          className="absolute right-3 top-1/2 -translate-y-1/2 z-20 w-8 h-8 flex items-center justify-center bg-bg-base/80 border border-border-faint hover:border-accent hover:text-accent transition-colors"
          aria-label="Next slide"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={1.5}>
            <path strokeLinecap="square" strokeLinejoin="miter" d="M9 5l7 7-7 7" />
          </svg>
        </button>

        {/* Gradient Overlay */}
        <div className="absolute inset-0 bg-gradient-to-t from-bg-base via-transparent to-transparent z-10 pointer-events-none"></div>

        {/* Image */}
        <div className="relative aspect-[4/3] sm:aspect-[16/10]">
          <Image
            src={currentSlide.src}
            alt={currentSlide.alt}
            fill
            className="object-contain"
            priority={currentIndex === 0}
          />
        </div>
      </div>

      {/* Controls Bar */}
      <div className="mt-4 flex items-center justify-between gap-4">
        {/* Slide Info */}
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium text-text-primary mb-1">
            {currentSlide.title}
          </p>
          <p className="text-xs text-text-muted truncate">
            {currentSlide.description}
          </p>
        </div>

        {/* Pagination Tabs */}
        <div className="flex items-center gap-1">
          {slides.map((_, index) => (
            <button
              key={index}
              onClick={() => goToSlide(index)}
              className={`px-2 py-1 text-xs font-mono transition-colors ${
                index === currentIndex
                  ? 'bg-accent text-bg-base'
                  : 'bg-bg-surface text-text-muted hover:text-text-primary border border-border-faint'
              }`}
              aria-label={`Go to slide ${index + 1}`}
            >
              {String(index + 1).padStart(2, '0')}
            </button>
          ))}
          <span className="text-xs text-text-muted font-mono ml-1">
            / {String(slides.length).padStart(2, '0')}
          </span>
        </div>
      </div>

      {/* Expanded Description (visible on larger screens) */}
      <p className="hidden sm:block mt-3 text-sm text-text-secondary leading-relaxed">
        {currentSlide.description}
      </p>
    </div>
  )
}
