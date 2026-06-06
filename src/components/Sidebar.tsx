"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { cn } from "@/lib/utils"
import { useState } from "react"

const navigation = [
  { name: "Dashboard", href: "/", icon: "📊" },
  { name: "Containers", href: "/containers", icon: "📦" },
  { name: "Sales", href: "/sales", icon: "💰" },
  { name: "Transactions", href: "/transactions", icon: "💳" },
  { name: "Expenses", href: "/expenses", icon: "📋" },
  { name: "Customers", href: "/customers", icon: "👥" },
  { name: "Suppliers", href: "/suppliers", icon: "🏭" },
  { name: "Ledger", href: "/ledger", icon: "📒" },
  { name: "Reports", href: "/reports", icon: "📈" },
]

const adminLinks = [
  { name: "Users", href: "/admin/users", icon: "👤" },
  { name: "Settings", href: "/admin/settings", icon: "⚙️" },
  { name: "Adjustments", href: "/admin/adjustments", icon: "🔧" },
  { name: "Commissions", href: "/admin/commissions", icon: "🏆" },
  { name: "Tax", href: "/admin/tax", icon: "🧾" },
  { name: "Ownership", href: "/admin/ownership", icon: "🏛️" },
]

export function Sidebar() {
  const pathname = usePathname()
  const [collapsed, setCollapsed] = useState(false)

  return (
    <aside className={cn(
      "bg-white border-r border-gray-200 flex flex-col transition-all duration-200",
      collapsed ? "w-16" : "w-60"
    )}>
      <div className="flex items-center justify-between p-4 border-b border-gray-200">
        {!collapsed && (
          <span className="font-bold text-blue-600 text-lg">Container</span>
        )}
        <button
          onClick={() => setCollapsed(!collapsed)}
          className="p-1 rounded hover:bg-gray-100 text-gray-500"
        >
          {collapsed ? "→" : "←"}
        </button>
      </div>

      <nav className="flex-1 overflow-y-auto py-2">
        {navigation.map((item) => {
          const isActive = pathname === item.href || pathname.startsWith(item.href + "/")
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 px-4 py-2.5 text-sm transition-colors",
                isActive
                  ? "bg-blue-50 text-blue-700 font-medium border-r-2 border-blue-600"
                  : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
              )}
            >
              <span className="text-lg">{item.icon}</span>
              {!collapsed && <span>{item.name}</span>}
            </Link>
          )
        })}

        {/* Admin section */}
        <div className={cn("pt-4 mt-4 border-t border-gray-200", collapsed && "px-2")}>
          {!collapsed && (
            <p className="px-4 text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">
              Admin
            </p>
          )}
          {adminLinks.map((item) => {
            const isActive = pathname.startsWith(item.href)
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "flex items-center gap-3 px-4 py-2.5 text-sm transition-colors",
                  isActive
                    ? "bg-purple-50 text-purple-700 font-medium border-r-2 border-purple-600"
                    : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
                )}
              >
                <span className="text-lg">{item.icon}</span>
                {!collapsed && <span>{item.name}</span>}
              </Link>
            )
          })}
        </div>
      </nav>
    </aside>
  )
}