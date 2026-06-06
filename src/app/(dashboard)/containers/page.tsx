import { createServerSupabaseClient } from "@/lib/supabase-server"
import { redirect } from "next/navigation"
import Link from "next/link"
import { Button } from "@/components/ui/button"

const statusColors: Record<string, string> = {
  planning: "bg-gray-100 text-gray-700",
  collecting_funds: "bg-yellow-100 text-yellow-700",
  purchasing: "bg-blue-100 text-blue-700",
  in_transit: "bg-indigo-100 text-indigo-700",
  selling: "bg-green-100 text-green-700",
  closed: "bg-gray-100 text-gray-500",
  archived: "bg-red-100 text-red-700",
}

export default async function ContainersPage() {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect("/login")

  const { data: containers } = await supabase
    .from("containers")
    .select("*, container_summary(*)")
    .order("created_at", { ascending: false })

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Containers</h1>
        <Link href="/containers/new">
          <Button className="bg-blue-600 hover:bg-blue-700 text-white">+ New Container</Button>
        </Link>
      </div>

      {containers && containers.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {containers.map((c: any) => {
            const s = c.container_summary?.[0]
            return (
              <Link key={c.id} href={`/containers/${c.id}`}
                className="bg-white rounded-lg shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow">
                <div className="flex items-center justify-between mb-3">
                  <h3 className="font-medium text-gray-900 truncate">{c.name}</h3>
                  <span className={`text-xs px-2 py-1 rounded-full ${statusColors[c.status] || ""}`}>
                    {c.status?.replace(/_/g, " ")}
                  </span>
                </div>
                {c.description && <p className="text-sm text-gray-500 mb-3 line-clamp-2">{c.description}</p>}
                <div className="text-xs text-gray-500 space-y-1">
                  <p>Currency: {c.primary_foreign_currency}</p>
                  <p>Sales: {s?.net_sales_pkr?.toLocaleString() || 0} PKR</p>
                  <p className={s?.net_profit_pkr >= 0 ? "text-green-600 font-medium" : "text-red-600 font-medium"}>
                    Profit: {s?.net_profit_pkr?.toLocaleString() || 0} PKR
                  </p>
                </div>
              </Link>
            )
          })}
        </div>
      ) : (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-12 text-center">
          <p className="text-gray-500 text-lg mb-2">No containers yet</p>
          <p className="text-gray-400 text-sm mb-4">Create your first container to begin trading.</p>
          <Link href="/containers/new">
            <Button className="bg-blue-600 hover:bg-blue-700 text-white">Create Container</Button>
          </Link>
        </div>
      )}
    </div>
  )
}