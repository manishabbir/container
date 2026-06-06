import { createServerSupabaseClient, createServerAdminClient } from "@/lib/supabase-server"
import { redirect } from "next/navigation"
import { Button } from "@/components/ui/button"

export default async function AdminUsersPage() {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect("/login")

  // Auto-create admin profile if it doesn't exist
  const { data: existingProfile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single()

  if (!existingProfile) {
    // First user to visit Admin gets admin role
    const adminClient = await createServerAdminClient()
    await adminClient.from("profiles").upsert({
      id: user.id,
      email: user.email,
      full_name: user.user_metadata?.full_name || user.email?.split("@")[0] || "Admin",
      role: "admin",
      country: "Pakistan",
      currency: "PKR",
      is_active: true,
      commission_rate: 0,
      commission_type: "none",
    })
  } else if (existingProfile.role !== "admin") {
    redirect("/")
  }

  const { data: users } = await supabase
    .from("profiles")
    .select("id, email, full_name, role, country, currency, is_active, commission_rate, commission_type, created_at")
    .order("created_at", { ascending: false })

  async function createUser(formData: FormData) {
    "use server"
    const adminClient = await createServerAdminClient()
    const { data: { user: currentUser } } = await adminClient.auth.getUser()
    if (!currentUser) redirect("/login")

    const email = formData.get("email") as string
    const password = formData.get("password") as string
    const full_name = formData.get("full_name") as string
    const role = formData.get("role") as string
    const country = formData.get("country") as string || "Pakistan"
    const currency = formData.get("currency") as string || "PKR"
    const commission_rate = parseFloat(formData.get("commission_rate") as string) || 0

    // Create auth user via admin API (needs service_role key)
    const { data: authUser, error: authError } = await adminClient.auth.admin.createUser({
      email, password, email_confirm: true,
    })

    if (authError) redirect(`/admin/users?error=${encodeURIComponent(authError.message)}`)

    if (authUser?.user) {
      const { error: profileError } = await supabase.from("profiles").insert({
        id: authUser.user.id, email, full_name, role,
        country, currency, is_active: true,
        created_by: currentUser.id,
        commission_rate, commission_type: "percentage",
        max_discount_percent: role === "inside_country" ? 10.0 : 0,
      })
      if (profileError) redirect(`/admin/users?error=${encodeURIComponent(profileError.message)}`)
    }
    redirect("/admin/users?message=User created successfully")
  }

  const roleColors: Record<string, string> = {
    admin: "bg-purple-100 text-purple-700",
    inside_country: "bg-blue-100 text-blue-700",
    abroad: "bg-green-100 text-green-700",
    viewer: "bg-gray-100 text-gray-700",
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">User Management</h1>
      </div>

      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Create New User</h2>
        <form action={createUser} className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
            <input name="full_name" required className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input name="email" type="email" required className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
            <input name="password" type="password" required className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
            <select name="role" required className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm">
              <option value="admin">Admin</option>
              <option value="inside_country">Inside Country</option>
              <option value="abroad">Abroad</option>
              <option value="viewer">Viewer</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Country</label>
            <input name="country" defaultValue="Pakistan" className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Currency</label>
            <input name="currency" defaultValue="PKR" className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Commission Rate (%)</label>
            <input name="commission_rate" type="number" defaultValue="0" min="0" max="100" step="0.1" className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
          </div>
          <div className="flex items-end">
            <Button type="submit" className="bg-blue-600 hover:bg-blue-700 text-white">Create User</Button>
          </div>
        </form>
      </div>

      <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Name</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Email</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Role</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Country</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Currency</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Commission</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {users?.map((u: any) => (
                <tr key={u.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium text-gray-900">{u.full_name}</td>
                  <td className="px-4 py-3 text-gray-600">{u.email}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-1 rounded-full ${roleColors[u.role] || "bg-gray-100"}`}>
                      {u.role?.replace(/_/g, " ")}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-gray-600">{u.country}</td>
                  <td className="px-4 py-3 text-gray-600">{u.currency}</td>
                  <td className="px-4 py-3 text-gray-600">{u.commission_rate}%</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-1 rounded-full ${u.is_active ? "bg-green-100 text-green-700" : "bg-red-100 text-red-700"}`}>
                      {u.is_active ? "Active" : "Inactive"}
                    </span>
                  </td>
                </tr>
              ))}
              {(!users || users.length === 0) && (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-gray-500">No users found</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}