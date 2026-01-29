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
import { useRouter } from 'next/navigation'
import { useState, useEffect } from 'react'
import { Wallet, CheckCircle } from 'lucide-react'

export default function Page() {
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [isSuccess, setIsSuccess] = useState(false)
  const [isValidSession, setIsValidSession] = useState<boolean | null>(null)
  const router = useRouter()

  useEffect(() => {
    const supabase = createClient()
    
    // Check if user has a valid session (from the reset link)
    supabase.auth.getSession().then(({ data: { session } }) => {
      setIsValidSession(!!session)
    })
  }, [])

  const handleResetPassword = async (e: React.FormEvent) => {
    e.preventDefault()
    const supabase = createClient()
    setIsLoading(true)
    setError(null)

    if (password !== confirmPassword) {
      setError('Passwords do not match')
      setIsLoading(false)
      return
    }

    if (password.length < 6) {
      setError('Password must be at least 6 characters')
      setIsLoading(false)
      return
    }

    try {
      const { error } = await supabase.auth.updateUser({
        password: password,
      })
      if (error) throw error
      setIsSuccess(true)
      
      // Redirect to login after 3 seconds
      setTimeout(() => {
        router.push('/auth/login')
      }, 3000)
    } catch (error: unknown) {
      setError(error instanceof Error ? error.message : 'An error occurred')
    } finally {
      setIsLoading(false)
    }
  }

  if (isValidSession === null) {
    return (
      <div className="flex min-h-svh w-full items-center justify-center bg-gradient-to-b from-slate-50 via-white to-slate-50 p-6 md:p-10">
        <div className="w-full max-w-sm">
          <div className="flex flex-col gap-6">
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
              <CardContent className="pt-6 text-center">
                <p className="text-muted-foreground">Loading...</p>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    )
  }

  if (!isValidSession) {
    return (
      <div className="flex min-h-svh w-full items-center justify-center bg-gradient-to-b from-slate-50 via-white to-slate-50 p-6 md:p-10">
        <div className="w-full max-w-sm">
          <div className="flex flex-col gap-6">
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
                <CardTitle className="text-2xl">Invalid or expired link</CardTitle>
                <CardDescription>
                  This password reset link is invalid or has expired.
                </CardDescription>
              </CardHeader>
              <CardContent className="text-center">
                <Link 
                  href="/auth/forgot-password"
                  className="text-sm text-emerald-600 underline underline-offset-4 hover:text-emerald-700"
                >
                  Request a new reset link
                </Link>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    )
  }

  if (isSuccess) {
    return (
      <div className="flex min-h-svh w-full items-center justify-center bg-gradient-to-b from-slate-50 via-white to-slate-50 p-6 md:p-10">
        <div className="w-full max-w-sm">
          <div className="flex flex-col gap-6">
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
                  <CheckCircle className="h-8 w-8 text-emerald-600" />
                </div>
                <CardTitle className="text-2xl">Password updated</CardTitle>
                <CardDescription>
                  Your password has been successfully reset
                </CardDescription>
              </CardHeader>
              <CardContent className="text-center">
                <p className="text-sm text-muted-foreground mb-4">
                  You will be redirected to the login page in a few seconds...
                </p>
                <Link 
                  href="/auth/login"
                  className="text-sm text-emerald-600 underline underline-offset-4 hover:text-emerald-700"
                >
                  Go to login now
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
              <CardTitle className="text-2xl">Reset password</CardTitle>
              <CardDescription>
                Enter your new password below
              </CardDescription>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleResetPassword}>
                <div className="flex flex-col gap-6">
                  <div className="grid gap-2">
                    <Label htmlFor="password">New Password</Label>
                    <Input
                      id="password"
                      type="password"
                      required
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="bg-white"
                    />
                  </div>
                  <div className="grid gap-2">
                    <Label htmlFor="confirm-password">Confirm Password</Label>
                    <Input
                      id="confirm-password"
                      type="password"
                      required
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      className="bg-white"
                    />
                  </div>
                  {error && <p className="text-sm text-red-500">{error}</p>}
                  <Button 
                    type="submit" 
                    className="w-full bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700" 
                    disabled={isLoading}
                  >
                    {isLoading ? 'Updating...' : 'Update password'}
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
