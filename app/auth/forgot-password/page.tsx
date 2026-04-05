'use client'

import { createClient } from '@/lib/supabase/client'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import Link from 'next/link'
import { useState } from 'react'
import { Wallet, Mail, ArrowLeft } from 'lucide-react'

export default function Page() {
  const [email, setEmail] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [isSuccess, setIsSuccess] = useState(false)

  const handleResetPassword = async (e: React.FormEvent) => {
    e.preventDefault()
    const supabase = createClient()
    setIsLoading(true)
    setError(null)

    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/auth/callback?next=/auth/reset-password`,
      })
      if (error) throw error
      setIsSuccess(true)
    } catch (error: unknown) {
      setError(error instanceof Error ? error.message : 'An error occurred')
    } finally {
      setIsLoading(false)
    }
  }

  if (isSuccess) {
    return (
      <div className="flex min-h-svh w-full items-center justify-center bg-gradient-to-b from-slate-50 via-white to-slate-50 p-6 md:p-10">
        <div className="w-full max-w-sm">
          <div className="flex flex-col gap-6">
            {/* Logo */}
            <div className="flex items-center justify-center gap-3">
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 text-white shadow-lg shadow-emerald-500/20">
                <Wallet className="h-6 w-6" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-foreground">Money Master</h1>
                <p className="text-xs text-muted-foreground">Track your finances</p>
              </div>
            </div>

            <Card className="border-slate-200">
              <CardHeader className="text-center">
                <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-emerald-100">
                  <Mail className="h-8 w-8 text-emerald-600" />
                </div>
                <CardTitle className="text-2xl">Check your email</CardTitle>
                <CardDescription>
                  We&apos;ve sent you a password reset link
                </CardDescription>
              </CardHeader>
              <CardContent className="text-center">
                <p className="text-sm text-muted-foreground mb-4">
                  Please check your email and click the reset link to create a new password.
                  The link will expire in 1 hour.
                </p>
                <Link 
                  href="/auth/login"
                  className="text-sm text-emerald-600 underline underline-offset-4 hover:text-emerald-700"
                >
                  Back to login
                </Link>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="flex min-h-svh w-full items-center justify-center bg-gradient-to-b from-slate-50 via-white to-slate-50 p-6 md:p-10">
      <div className="w-full max-w-sm">
        <div className="flex flex-col gap-6">
          {/* Logo */}
          <div className="flex items-center justify-center gap-3">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 text-white shadow-lg shadow-emerald-500/20">
              <Wallet className="h-6 w-6" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-foreground">Money Master</h1>
              <p className="text-xs text-muted-foreground">Track your finances</p>
            </div>
          </div>

          <Card className="border-slate-200">
            <CardHeader>
              <CardTitle className="text-2xl">Forgot password?</CardTitle>
              <CardDescription>
                Enter your email and we&apos;ll send you a reset link
              </CardDescription>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleResetPassword}>
                <div className="flex flex-col gap-6">
                  <div className="grid gap-2">
                    <Label htmlFor="email">Email</Label>
                    <Input
                      id="email"
                      type="email"
                      placeholder="m@example.com"
                      required
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="bg-white"
                    />
                  </div>
                  {error && <p className="text-sm text-red-500">{error}</p>}
                  <Button 
                    type="submit" 
                    className="w-full bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700" 
                    disabled={isLoading}
                  >
                    {isLoading ? 'Sending...' : 'Send reset link'}
                  </Button>
                </div>
                <div className="mt-4 text-center">
                  <Link
                    href="/auth/login"
                    className="inline-flex items-center gap-1 text-sm text-emerald-600 underline-offset-4 hover:underline"
                  >
                    <ArrowLeft className="h-4 w-4" />
                    Back to login
                  </Link>
                </div>
              </form>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
