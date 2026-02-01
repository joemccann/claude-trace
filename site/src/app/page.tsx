import Image from 'next/image'
import { Nav } from '@/components/Nav'
import { Hero } from '@/components/Hero'
import { Features } from '@/components/Features'
import { CLI } from '@/components/CLI'
import { Footer } from '@/components/Footer'

export default function Home() {
  return (
    <main className="min-h-screen bg-bg-primary">
      <Nav />
      <Hero />
      <Features />
      <CLI />
      <Footer />
    </main>
  )
}
