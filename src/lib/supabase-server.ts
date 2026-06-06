import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createServerSupabaseClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {
            // Can be ignored if middleware refreshes sessions
          }
        },
      },
    }
  )
}

export async function createServerAdminClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll() {
          // No session persistence needed for admin client
        },
      },
    }
  )
}

export async function ensureProfileExists(userId: string, email: string, fullName?: string) {
  const adminClient = await createServerAdminClient()
  const { data: existing } = await adminClient
    .from("profiles")
    .select("id")
    .eq("id", userId)
    .single()

  if (!existing) {
    await adminClient.from("profiles").insert({
      id: userId,
      email,
      full_name: fullName || email?.split("@")[0] || "User",
      role: "inside_country",
      country: "Pakistan",
      currency: "PKR",
      is_active: true,
      commission_rate: 0,
      commission_type: "none",
      max_discount_percent: 10.0,
    })
  }
}
