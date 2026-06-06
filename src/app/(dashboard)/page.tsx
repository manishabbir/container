import { createServerSupabaseClient } from "@/lib/supabase-server"
import { redirect } from "next/navigation"

export default async function DashboardPage() {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect("/login")

  // Fetch containers
  const { data: containers } = await supabase
    .from("containers")
    .select("id, name, status, primary_foreign_currency, created_at, created_by")
    .order("created_at", { ascending: false })

  // Fetch pending sales
  const { data: pendingSales } = await supabase
    .from("sales")
    .select("id, total_amount_pkr, created_at, customers(name)")
    .eq("status", "pending")

  // Fetch pending transactions
  const { data: pendingTransactions } = await supabase
    .from("transactions")
    .select("id, amount_home, transaction_type, created_at, description")
    .eq("status", "pending")

  const totalContainers = containers?.length || 0
  const activeContainers = containers?.filter(c => c.status !== "closed" && c.status !== "archived").length || 0
  const pendingCount = (pendingSales?.length || 0) + (pendingTransactions?.length || 0)

  const statusColors: Record<string, string> = {
    planning: "bg-gray-100 text-gray-700",
    collecting_funds: "bg-yellow-100 text-yellow-700",
    purchasing: "bg-blue-100 text-blue-700",
    in_transit: "bg-indigo-100 text-indigo-700",
    selling: "bg-green-100 text-green-700",
    closed: "bg-gray-100 text-gray-500",
    archived: "bg-red-100 text-red-700",
  }

  return (
    <div className="space-y-6">
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-blue-50 rounded-lg">
              <svg className="h-6 w-6 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
              </svg>
            </div>
            <div>
              <p className="text-sm text-gray-500">Total Containers</p>
              <p className="text-2xl font-bold text-gray-900">{totalContainers}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-green-50 rounded-lg">
              <svg className="h-6 w-6 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <p className="text-sm text-gray-500">Active Containers</p>
              <p className="text-2xl font-bold text-green-600">{activeContainers}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-orange-50 rounded-lg">
              <svg className="h-6 w-6 text-orange-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <p className="text-sm text-gray-500">Pending Approvals</p>
              <p className="text-2xl font-bold text-orange-600">{pendingCount}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Pending Approvals */}
      {(pendingSales && pendingSales.length > 0) || (pendingTransactions && pendingTransactions.length > 0) ? (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Pending Approvals</h2>
          <div className="space-y-3">
            {pendingSales?.map((sale: any) => (
              <div key={sale.id} className="flex items-center justify-between p-3 bg-yellow-50 rounded-lg">
                <div>
                  <p className="text-sm font-medium text-gray-900">Sale: {sale.total_amount_pkr?.toLocaleString()} PKR</p>
                  <p className="text-xs text-gray-500">
                    Customer: {sale.customers?.name || "N/A"} · {new Date(sale.created_at).toLocaleDateString()}
                  </p>
                </div>
                <span className="text-xs bg-yellow-100 text-yellow-700 px-2 py-1 rounded-full">Pending</span>
              </div>
            ))}
            {pendingTransactions?.map((tx: any) => (
              <div key={tx.id} className="flex items-center justify-between p-3 bg-blue-50 rounded-lg">
                <div>
                  <p className="text-sm font-medium text-gray-900">
                    {tx.transaction_type === "fund_transfer" ? "Fund Transfer" : "Transaction"}: {tx.amount_home?.toLocaleString()} PKR
                  </p>
                  <p className="text-xs text-gray-500">{tx.description || ""} · {new Date(tx.created_at).toLocaleDateString()}</p>
                </div>
                <span className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full">Pending</span>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6 text-center">
          <p className="text-gray-500">No pending approvals</p>
        </div>
      )}

      {/* Container Overview Cards */}
      <h2 className="text-lg font-semibold text-gray-900">Containers</h2>
      {containers && containers.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {containers.map((container: any) => (
            <a
              key={container.id}
              href={`/containers/${container.id}`}
              className="bg-white rounded-lg shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow cursor-pointer"
            >
              <div className="flex items-center justify-between mb-3">
                <h3 className="font-medium text-gray-900 truncate">{container.name}</h3>
                <span className={`text-xs px-2 py-1 rounded-full ${statusColors[container.status] || "bg-gray-100 text-gray-700"}`}>
                  {container.status?.replace(/_/g, " ")}
                </span>
              </div>
              <p className="text-xs text-gray-500">Currency: {container.primary_foreign_currency}</p>
              <p className="text-xs text-gray-500">Created: {new Date(container.created_at).toLocaleDateString()}</p>
            </a>
          ))}
        </div>
      ) : (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-12 text-center">
          <p className="text-gray-500 text-lg mb-2">No containers yet</p>
          <p className="text-gray-400 text-sm">Create your first container to get started.</p>
        </div>
      )}
    </div>
  )
}