import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { WebhookReceiver, EgressClient } from "https://esm.sh/livekit-server-sdk@1.2.7"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const apiKey = Deno.env.get('LIVEKIT_API_KEY')
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')
    let livekitUrl = Deno.env.get('LIVEKIT_URL')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (livekitUrl?.startsWith('wss://')) livekitUrl = livekitUrl.replace('wss://', 'https://')

    const receiver = new WebhookReceiver(apiKey!, apiSecret!)
    const body = await req.text()
    const event = receiver.receive(body, req.headers.get('Authorization'))

    const supabase = createClient(supabaseUrl!, supabaseKey!)
    const egressClient = new EgressClient(livekitUrl!, apiKey!, apiSecret!)

    console.log(`[WEBHOOK] Event: ${event.event} | Room: ${event.room?.name}`)

    // --- الحل الجذري: مراقبة المدرس وانتهاء القاعة ---

    // 1. إذا انتهت القاعة تماماً
    if (event.event === 'room_finished') {
      const roomName = event.room?.name
      if (roomName) {
        const activeEgresses = await egressClient.listEgress({ roomName, active: true })
        for (const e of activeEgresses) {
          await egressClient.stopEgress(e.egressId)
          console.log(`[RADICAL] Room finished. Stopped egress: ${e.egressId}`)
        }
      }
    }

    // 2. إذا غادر المدرس القاعة (سواء قفل التطبيق أو النت فصل)
    if (event.event === 'participant_disconnected') {
      const identity = event.participant?.identity
      const roomName = event.room?.name
      
      // نتحقق إذا كان اللي خرج هو المدرس (identity بتبدأ بـ teacher_)
      if (identity?.startsWith('teacher_') && roomName) {
        console.log(`[RADICAL] Teacher ${identity} left. Checking for active recordings...`)
        const activeEgresses = await egressClient.listEgress({ roomName, active: true })
        for (const e of activeEgresses) {
          await egressClient.stopEgress(e.egressId)
          console.log(`[RADICAL] Stopped egress ${e.egressId} because teacher left.`)
        }
      }
    }

    // 3. المعالجة العادية لانتهاء التسجيل (تحديث الداتابيز بالرابط)
    if (event.event === 'egress_ended') {
      const egressId = event.egressInfo?.egressId
      const filePath = event.egressInfo?.file?.filepath
      const publicDomain = Deno.env.get('R2_PUBLIC_DOMAIN')

      if (egressId && filePath && publicDomain) {
        const finalVideoUrl = `${publicDomain}/${filePath}`

        await supabase
          .from('recordings')
          .update({
            status: 'completed',
            video_url: finalVideoUrl,
            completed_at: new Date().toISOString()
          })
          .eq('egress_id', egressId)

        const { data: rec } = await supabase
          .from('recordings')
          .select('session_id')
          .eq('egress_id', egressId)
          .single()

        if (rec) {
          await supabase
            .from('sessions')
            .update({ is_recording: false, is_recording_paused: false })
            .eq('id', rec.session_id)
        }
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Webhook error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
