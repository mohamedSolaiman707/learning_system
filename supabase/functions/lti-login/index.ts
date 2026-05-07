import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

serve(async (req) => {
  // السماح بطلبات CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  const url = new URL(req.url)
  const iss = url.searchParams.get('iss')
  const login_hint = url.searchParams.get('login_hint')
  const target_link_uri = url.searchParams.get('target_link_uri')
  const lti_message_hint = url.searchParams.get('lti_message_hint')

  if (!iss || !login_hint || !target_link_uri) {
    return new Response("Missing required parameters", { status: 400 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  // جلب إعدادات الـ LMS بناءً على الـ Issuer (iss)
  const { data: config, error } = await supabase
    .from('lms_configs')
    .select('*')
    .eq('issuer', iss)
    .single()

  if (error || !config) {
    console.error("LMS Config Error:", error)
    return new Response("LMS platform not registered", { status: 401 })
  }

  // بناء رابط التحويل لصفحة تسجيل الدخول في Moodle/Canvas
  const authUrl = new URL(config.auth_endpoint)
  authUrl.searchParams.set('scope', 'openid')
  authUrl.searchParams.set('response_type', 'id_token')
  authUrl.searchParams.set('client_id', config.client_id)
  authUrl.searchParams.set('redirect_uri', config.redirect_uri ?? target_link_uri)
  authUrl.searchParams.set('login_hint', login_hint)
  authUrl.searchParams.set('nonce', crypto.randomUUID())
  authUrl.searchParams.set('state', crypto.randomUUID())
  authUrl.searchParams.set('response_mode', 'form_post')
  if (lti_message_hint) {
    authUrl.searchParams.set('lti_message_hint', lti_message_hint)
  }

  return Response.redirect(authUrl.toString(), 302)
})
