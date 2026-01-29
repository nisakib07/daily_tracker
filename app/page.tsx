import { Dashboard } from "@/components/dashboard"
import { AppHeader } from "@/components/app-header"

export default function Page() {
  return (
    <div className="min-h-screen flex flex-col">
      <AppHeader />
      <div className="flex-1">
        <Dashboard />
      </div>
    </div>
  )
}
