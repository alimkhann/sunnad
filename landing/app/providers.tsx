'use client'

import { useEffect } from 'react'
import posthog from 'posthog-js'
import { PostHogProvider as PHProvider } from 'posthog-js/react'
import { captureLandingEvent } from '@/lib/analytics'

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

function resolveReplayEnabled(): boolean {
  if (typeof window === 'undefined') return false
  if (process.env.NODE_ENV !== 'production') return true

  const key = 'sunnad_posthog_replay_sampled'
  const existing = window.localStorage.getItem(key)
  if (existing === '1') return true
  if (existing === '0') return false

  const sampled = Math.random() < 0.2
  window.localStorage.setItem(key, sampled ? '1' : '0')
  return sampled
}

function hashMessage(value: string): string {
  let hash = 0x811c9dc5
  for (let i = 0; i < value.length; i += 1) {
    hash ^= value.charCodeAt(i)
    hash = Math.imul(hash, 0x01000193)
  }
  return (hash >>> 0).toString(16)
}

export function PostHogProvider({ children }: PostHogProviderProps) {
  useEffect(() => {
    if (!isPosthogEnabled()) return

    const replayEnabled = resolveReplayEnabled()

    if (!posthog.__loaded) {
      posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY as string, {
        api_host:
          process.env.NEXT_PUBLIC_POSTHOG_HOST ?? 'https://eu.i.posthog.com',
        person_profiles: 'identified_only',
        // We capture pageviews and key actions explicitly
        capture_pageview: false,
        autocapture: false,
        disable_session_recording: !replayEnabled,
        session_recording: {
          maskAllInputs: true,
        },
      })
    }

    const onWindowError = (event: ErrorEvent) => {
      const normalized = `${event.message ?? ''}|${event.filename ?? ''}|${String(event.lineno ?? '')}`
      captureLandingEvent('landing_error_captured', {
        error_type: 'window_error',
        source: event.filename || 'window',
        message_hash: hashMessage(normalized.toLowerCase()),
      })
    }

    const onUnhandledRejection = (event: PromiseRejectionEvent) => {
      const reason = event.reason instanceof Error ? event.reason.message : String(event.reason ?? '')
      captureLandingEvent('landing_error_captured', {
        error_type: 'unhandled_rejection',
        source: 'promise',
        message_hash: hashMessage(reason.toLowerCase()),
      })
    }

    window.addEventListener('error', onWindowError)
    window.addEventListener('unhandledrejection', onUnhandledRejection)

    return () => {
      window.removeEventListener('error', onWindowError)
      window.removeEventListener('unhandledrejection', onUnhandledRejection)
    }
  }, [])

  return <PHProvider client={posthog}>{children}</PHProvider>
}
