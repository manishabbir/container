import { createServerSupabaseClient, createServerAdminClient } from "@/lib/supabase-server"
import { redirect } from "next/navigation"
import { Button } from "@/components/ui/button"

export default function NewContainerPage() {
  async function createContainer(formData: FormData) {
    "use server"
    // Use session client to read cookies
    const sessionClient = await createServerSupabaseClient()
    const { data: { user } } = await sessionClient.auth.getUser()
    if (!user) redirect("/login")

    // Use admin client to bypass RLS for writes
    const supabase = createServerAdminClient()

    const name = formData.get("name") as string
    const description = formData.get("description") as string || ""
    const currency = formData.get("currency") as string || "USD"
    const tax_rate = parseFloat(formData.get("tax_rate") as string) || 0

    const { error } = await supabase.from("containers").insert({
      name,
      description,
      primary_foreign_currency: currency,
      tax_rate_pkr: tax_rate,
      created_by: user.id,
      status: "planning",
    })

    if (error) redirect(`/containers/new?error=${encodeURIComponent(error.message)}`)
    redirect("/containers")
  }

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Create New Container</h1>
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <form action={createContainer} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Container Name *</label>
            <input name="name" required className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" placeholder="e.g., Container #1 - July 2026" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
            <textarea name="description" rows={3} className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" placeholder="Optional description" />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Primary Currency *</label>
              <select name="currency" className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm">
                <option value="USD">USD - US Dollar</option>
                <option value="AED">AED - UAE Dirham</option>
                <option value="SAR">SAR - Saudi Riyal</option>
                <option value="EUR">EUR - Euro</option>
                <option value="GBP">GBP - British Pound</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Tax Rate (%)</label>
              <input name="tax_rate" type="number" defaultValue="0" min="0" max="100" step="0.1" className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
            </div>
          </div>
          <div className="pt-2">
            <Button type="submit" className="bg-blue-600 hover:bg-blue-700 text-white">Create Container</Button>
          </div>
        </form>
      </div>
    </div>
  )
}