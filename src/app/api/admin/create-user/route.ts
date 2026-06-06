import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { email, password, full_name, role, country, currency, commission_rate, created_by } = body

    if (!email || !password || !full_name || !role) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
      email, password, email_confirm: true,
    })

    if (authError) {
      return NextResponse.json({ error: authError.message }, { status: 400 })
    }

    if (authUser?.user) {
      const { error: profileError } = await supabase.from('profiles').insert({
        id: authUser.user.id,
        email,
        full_name,
        role,
        country: country || 'Pakistan',
        currency: currency || 'PKR',
        is_active: true,
        created_by,
        commission_rate: commission_rate || 0,
        commission_type: 'percentage',
        max_discount_percent: role === 'inside_country' ? 10.0 : 0,
      })

      if (profileError) {
        return NextResponse.json({ error: profileError.message }, { status: 400 })
      }
    }

    return NextResponse.json({ success: true, userId: authUser?.user?.id })
  } catch (err: any) {
    return NextResponse.json({ error: err.message || 'Internal server error' }, { status: 500 })
  }
}