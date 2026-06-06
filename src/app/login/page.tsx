import { createServerSupabaseClient } from "@/lib/supabase-server"
import { redirect } from "next/navigation"
import { Button } from "@/components/ui/button"

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>
}) {
  const { error: errorParam, message } = await searchParams

  async function signIn(formData: FormData) {
    "use server"
    const email = formData.get("email") as string
    const password = formData.get("password") as string
    const supabase = await createServerSupabaseClient()

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })

    if (error) {
      let msg = "Invalid email or password"
      if (error.message?.includes("rate_limit")) msg = "Too many attempts. Please try again later."
      if (error.message?.includes("disabled") || error.message?.includes("inactive")) msg = "Account has been deactivated. Contact admin."
      redirect(`/login?error=${encodeURIComponent(msg)}`)
    }

    // Auto-create profile if it doesn't exist (first login)
    if (data?.user) {
      const { data: existing } = await supabase
        .from("profiles")
        .select("id")
        .eq("id", data.user.id)
        .single()

      if (!existing) {
        await supabase.from("profiles").insert({
          id: data.user.id,
          email: data.user.email,
          full_name: email.split("@")[0],
          role: "inside_country",
          country: "Pakistan",
          currency: "PKR",
          is_active: true,
          commission_rate: 0,
          commission_type: "none",
        })
      }
    }

    redirect("/")
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-50 to-blue-50">
      <div className="w-full max-w-md space-y-8 p-8 bg-white rounded-xl shadow-lg">
        <div className="text-center">
          <div className="mx-auto h-12 w-12 bg-blue-600 rounded-lg flex items-center justify-center mb-4">
            <svg className="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
            </svg>
          </div>
          <h1 className="text-2xl font-bold text-gray-900">Container Trade</h1>
          <p className="text-gray-500 mt-2">Sign in to your account</p>
        </div>

        {errorParam && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
            {errorParam}
          </div>
        )}
        {message && (
          <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg text-sm">
            {message}
          </div>
        )}

        <form action={signIn} className="space-y-6">
          <div>
            <label htmlFor="email" className="block text-sm font-medium text-gray-700">
              Email
            </label>
            <input
              id="email"
              name="email"
              type="email"
              autoComplete="email"
              required
              className="mt-1 block w-full px-3 py-2.5 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="you@example.com"
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-700">
              Password
            </label>
            <input
              id="password"
              name="password"
              type="password"
              autoComplete="current-password"
              required
              className="mt-1 block w-full px-3 py-2.5 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="••••••••"
            />
          </div>

          <Button type="submit" className="w-full bg-blue-600 hover:bg-blue-700 text-white">
            Sign In
          </Button>
        </form>

        <div className="text-center">
          <a
            href="/forgot-password"
            className="text-sm text-blue-600 hover:text-blue-800"
          >
            Forgot your password?
          </a>
        </div>
      </div>
    </div>
  )
}