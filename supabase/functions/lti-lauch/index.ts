import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-client@2.39.3'
import * as djwt from "https://deno.land/x/djwt@v2.8/mod.ts"

serve(async (req) => {
  if (req.method !== 'POST') return new Response("Method not allowed", { status: 405 })

  try {
    const formData = await req.formData()
    const id_token = formData.get('id_token') as string

    if (!id_token) throw new Error("Missing id_token")

    // 1. فك التوكن واستخراج البيانات
    const [header, payload, signature] = djwt.decode(id_token) as any
    const sub = payload.sub 
    const email = payload.email
    const name = payload.name
    
    const context = payload['https://purl.imsglobal.org/spec/lti/claim/context'] || {}
    const lms_id = context.id 
    const courseTitle = context.title || "حصة دراسية"
    const roles = payload['https://purl.imsglobal.org/spec/lti/claim/roles'] || []
    const isInstructor = roles.some((role: string) => role.includes('Instructor'))

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // 2. إدارة المستخدم (Provisioning)
    let { data: profile } = await supabase.from('profiles').select('id, role').eq('external_id', sub).maybeSingle()

    if (!profile) {
      const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
        email: email,
        email_confirm: true,
        user_metadata: { full_name: name },
        password: crypto.randomUUID()
      })
      if (authError || !authUser.user) throw authError || new Error("User creation failed")

      const { data: newProfile } = await supabase.from('profiles').update({
        external_id: sub,
        role: isInstructor ? 'teacher' : 'student'
      }).eq('id', authUser.user.id).select().single()
      profile = newProfile
    }

    // 3. إدارة الحصة (Auto-Session)
    let { data: session } = await supabase.from('sessions').select('id').eq('lms_id', lms_id).maybeSingle()

    if (!session && isInstructor) {
      const { data: newSession } = await supabase.from('sessions').insert({
        lms_id: lms_id,
        title: courseTitle,
        teacher_id: profile.id,
        start_time: new Date().toISOString(),
        class_code: Math.random().toString(36).substring(2, 8).toUpperCase()
      }).select().single()
      session = newSession
    }

    // --- ميزة التحضير التلقائي (Automatic Attendance) ---
    if (session && profile.role === 'student') {
      await supabase.from('attendance').upsert({
        session_id: session.id,
        student_id: profile.id,
        status: 'present',
        joined_at: new Date().toISOString()
      }, { onConflict: 'session_id,student_id' })
    }

    // 4. تسجيل الدخول السحري
    const { data: loginData, error: linkError } = await supabase.auth.admin.generateLink({
      type: 'magiclink',
      email: email,
    })
    if (linkError) throw linkError

    // 5. التحويل النهائي
    const appUrl = Deno.env.get('APP_URL') || "https://your-app.vercel.app"
    const redirectUrl = `${appUrl}/#/?lms_id=${lms_id}`
    const finalUrl = `${loginData.properties.action_link}&redirect_to=${encodeURIComponent(redirectUrl)}`

    return Response.redirect(finalUrl, 302)

  } catch (error) {
    console.error("LTI Launch Error:", error)
    return new Response(`Error: ${error.message}`, { status: 500 })
  }
})