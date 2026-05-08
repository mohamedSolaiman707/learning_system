import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7'

serve(async (req) => {
  const url = new URL(req.url);
  const searchParams = Object.fromEntries(url.searchParams.entries());

  let bodyParams = {};
  if (req.method === 'POST') {
    try {
      const formData = await req.formData();
      bodyParams = Object.fromEntries(formData.entries());
    } catch (e) {
      console.log("Not a form post");
    }
  }

  const iss = searchParams.iss || bodyParams.iss;
  const login_hint = searchParams.login_hint || bodyParams.login_hint;
  const target_link_uri = searchParams.target_link_uri || bodyParams.target_link_uri;

  // إذا نقصت البيانات، اعرض صفحة تشخيص للمستخدم
  if (!iss || !login_hint) {
    const debugInfo = JSON.stringify({
      method: req.method,
      url: req.url,
      queryParams: searchParams,
      postParams: bodyParams,
      headers: Object.fromEntries(req.headers.entries())
    }, null, 2);

    return new Response(`
      <div style="font-family: sans-serif; padding: 20px; border: 2px solid red; border-radius: 10px;">
        <h2 style="color: red;">خطأ في بيانات الربط (LTI Login Error)</h2>
        <p>مودل لم يرسل البيانات المطلوبة لبدء الدخول. يرجى التأكد من إعدادات الأداة.</p>
        <h3>البيانات المستلمة للتشخيص (Debug Info):</h3>
        <pre style="background: #f4f4f4; padding: 15px; overflow: auto;">${debugInfo}</pre>
        <p>تأكد أن رابط <b>Initiate login URL</b> في مودل هو:<br>
        <code>https://jwjpyzpesfbwalgvpioo.supabase.co/functions/v1/lti-login</code></p>
      </div>
    `, {
      status: 400,
      headers: { "Content-Type": "text/html; charset=UTF-8" }
    });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  const cleanIss = iss.replace(/\/$/, "");
  const { data: config, error } = await supabase
    .from('lms_configs')
    .select('*')
    .or(`issuer.eq.${cleanIss},issuer.eq.${iss}`)
    .maybeSingle();

  if (error || !config) {
    return new Response(`LMS not registered for issuer: ${iss}. Please add it to lms_configs table.`, { status: 401 });
  }

  const authUrl = new URL(config.auth_endpoint);
  authUrl.searchParams.set('scope', 'openid');
  authUrl.searchParams.set('response_type', 'id_token');
  authUrl.searchParams.set('client_id', config.client_id);
  authUrl.searchParams.set('redirect_uri', config.redirect_uri || target_link_uri || "");
  authUrl.searchParams.set('login_hint', login_hint);
  authUrl.searchParams.set('nonce', crypto.randomUUID());
  authUrl.searchParams.set('state', crypto.randomUUID());
  authUrl.searchParams.set('response_mode', 'form_post');

  const lti_message_hint = searchParams.lti_message_hint || bodyParams.lti_message_hint;
  if (lti_message_hint) {
    authUrl.searchParams.set('lti_message_hint', lti_message_hint.toString());
  }

  return Response.redirect(authUrl.toString(), 302);
})