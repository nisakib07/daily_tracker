import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Wallet, Mail } from 'lucide-react'
import Link from 'next/link'

export default function Page() {
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
                We&apos;ve sent you a confirmation link
              </CardDescription>
            </CardHeader>
            <CardContent className="text-center">
              <p className="text-sm text-muted-foreground mb-4">
                Please check your email and click the confirmation link to activate your account. 
                Once confirmed, you can start tracking your finances.
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
