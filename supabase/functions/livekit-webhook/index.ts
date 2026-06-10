import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { WebhookReceiver } from "https://esm.sh/livekit-server-sdk@1.2.7"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const apiKey = Deno.env.get('LIVEKIT_API_KEY')
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    const receiver = new WebhookReceiver(apiKey!, apiSecret!)
    const body = await req.text()
    const event = receiver.receive(body, req.headers.get('Authorization'))

    const supabase = createClient(supabaseUrl!, supabaseKey!)

    console.log(`Received LiveKit event: ${event.event}`, event.egressInfo?.egressId)

    if (event.event === 'egress_ended') {
      const egressId = event.egressInfo?.egressId
      const filePath = event.egressInfo?.file?.filepath
      const publicDomain = Deno.env.get('R2_PUBLIC_DOMAIN')

      if (egressId && filePath && publicDomain) {
        const finalVideoUrl = `${publicDomain}/${filePath}`

        // تحديث واحد نهائي فيه كل البيانات
        const { error: updateError } = await supabase
          .from('recordings')
          .update({
            status: 'completed',
            video_url: finalVideoUrl,
            completed_at: new Date().toISOString()
          })
          .eq('egress_id', egressId)

        if (updateError) console.error('Error updating recording:', updateError)

        // تحديث حالة الحصة الأصلية
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
      } else {
        console.warn('Missing info for completion:', { egressId, filePath, publicDomain })
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