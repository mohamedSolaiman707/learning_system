import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-client@2.39.3'
import * as djwt from "https://deno.land/x/djwt@v2.8/mod.ts"

serve(async (req) => {
  if (req.method !== 'POST') return new Response("Method not allowed", { status: 405 })

  const formData = await req.formData()
  const id_token = formData.get('id_token') as string

  // 1. فك التوكن بدون تحقق أولاً لمعرفة من هو الـ Issuer
  const [header, payload, signature] = djwt.decode(id_token)
  const iss = (payload as any).iss
  const sub = (payload as any).sub // ID المستخدم في Moodle
  const email = (payload as any).email
  const name = (payload as any).name

  // جلب إعدادات المنصة من قاعدة البيانات
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const { data: config } = await supabase.from('lms_configs').select('*').eq('issuer', iss).single()

  // ملاحظة: هنا يجب إضافة كود للتحقق من التوقيع (Signature Validation) باستخدام JWKS الخاص بـ Moodle

  // 2. البحث عن المستخدم أو إنشاؤه في Supabase Auth
  // نستخدم الـ 'sub' كـ external_id الذي أضفناه للجداول سابقاً
  let { data: profile } = await supabase.from('profiles').select('id').eq('external_id', sub).maybeSingle()

  if (!profile) {
    // إنشاء مستخدم جديد صامتاً
    const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
      email: email,
      email_confirm: true,
      user_metadata: { full_name: name },
      password: crypto.randomUUID() // باسورد عشوائي لأن الدخول عبر LTI
    })

    if (newUser.user) {
      await supabase.from('profiles').update({
        external_id: sub,
        role: (payload as any)['https://purl.imsglobal.org/spec/lti/claim/roles'].includes('Instructor') ? 'teacher' : 'student'
      }).eq('id', newUser.user.id)
      profile = { id: newUser.user.id }
    }
  }

  // 3. إنشاء Session للمستخدم للتحويل للتطبيق
  const { data: loginData } = await supabase.auth.admin.generateLink({
    type: 'magiclink',
    email: email
  })

  // 4. التحويل لغرفة الفيديو في تطبيق Flutter Web
  // الرابط النهائي الذي سيضعه العميل في Moodle
  const lms_id = (payload as any)['https://purl.imsglobal.org/spec/lti/claim/context'].id
  const redirectUrl = `${Deno.env.get('APP_URL')}/#/video-room?lms_id=${lms_id}`

  return Response.redirect(loginData.properties.action_link + "&redirect_to=" + encodeURIComponent(redirectUrl), 302)
})