'use client'

import { useEffect } from 'react'
import posthog from 'posthog-js'
import { PostHogProvider as PHProvider } from 'posthog-js/react'

type PostHogProviderProps = {
  children: React.ReactNode
}

function isPosthogEnabled(): boolean {
  if (typeof window === 'undefined') return false

  const key = process.env.NEXT_PUBLIC_POSTHOG_KEY
  if (!key) return false

  // Disable in automated/test environments by default
  if (process.env.NODE_ENV === 'test') return false

  return true
}

export function PostHogProvider({ children }: PostHogProviderProps) {
  useEffect(() => {
    if (!isPosthogEnabled()) return

    if (!posthog.__loaded) {
      posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY as string, {
        api_host:
          process.env.NEXT_PUBLIC_POSTHOG_HOST ?? 'https://eu.i.posthog.com',
        person_profiles: 'identified_only',
        // We capture pageviews and key actions explicitly
        capture_pageview: false,
        autocapture: false,
      })
    }
  }, [])

  return <PHProvider client={posthog}>{children}</PHProvider>
}

