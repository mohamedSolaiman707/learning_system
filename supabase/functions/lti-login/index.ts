import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7"

serve(async (req) => {
  // دعم Access-Control-Allow-Origin للمنادات العابرة للمواقع
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  let params: any = {};
  
  // 1. محاولة قراءة المعلمات من URL (GET)
  const url = new URL(req.url);
  params = Object.fromEntries(url.searchParams.entries());

  // 2. محاولة قراءة المعلمات من Body (POST) إذا كانت GET فارغة
  if (req.method === 'POST') {
    try {
      const formData = await req.formData();
      const bodyParams = Object.fromEntries(formData.entries());
      params = { ...params, ...bodyParams };
    } catch (e) {
      console.log("Error parsing POST body in login");
    }
  }

  const iss = params.iss?.toString().trim();
  const login_hint = params.login_hint?.toString().trim();
  const lti_message_hint = params.lti_message_hint?.toString().trim();

  // إذا لم نجد المعلمات، سنظهر رسالة تشخيصية لمعرفة ماذا يرسل مودل بالضبط
  if (!iss || !login_hint) {
    return new Response(`Error: Missing OIDC parameters. Method: ${req.method}. Received: ${JSON.stringify(params)}`, { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const cleanIss = iss.replace(/\/$/, "");
  const { data: config } = await supabase
    .from('lms_configs')
    .select('*')
    .or(`issuer.eq.${cleanIss},issuer.eq.${iss}`)
    .maybeSingle();

  if (!config) {
    return new Response(`LMS Config not found for: ${iss}`, { status: 404 });
  }

  const authUrl = new URL(config.auth_endpoint.trim());
  authUrl.searchParams.set('client_id', config.client_id.trim());
  authUrl.searchParams.set('redirect_uri', config.redirect_uri.trim());
  authUrl.searchParams.set('response_type', 'id_token');
  authUrl.searchParams.set('scope', 'openid');
  authUrl.searchParams.set('response_mode', 'form_post');
  authUrl.searchParams.set('login_hint', login_hint);
  authUrl.searchParams.set('nonce', crypto.randomUUID());
  authUrl.searchParams.set('state', crypto.randomUUID());
  authUrl.searchParams.set('prompt', 'none');

  if (lti_message_hint) {
    authUrl.searchParams.set('lti_message_hint', lti_message_hint);
  }

  return Response.redirect(authUrl.toString(), 302);
})
