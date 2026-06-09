import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { EgressClient, EncodedFileType } from "https://esm.sh/livekit-server-sdk@1.2.7"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { action, roomName, sessionId, title } = await req.json()
    console.log(`[REC] Processing: ${action} | Session: ${sessionId}`)

    const apiKey = Deno.env.get('LIVEKIT_API_KEY')
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')
    let livekitUrl = Deno.env.get('LIVEKIT_URL')

    if (!apiKey || !apiSecret || !livekitUrl) {
      throw new Error('Required LiveKit secrets are missing (API_KEY, URL)')
    }

    if (livekitUrl.startsWith('wss://')) {
      livekitUrl = livekitUrl.replace('wss://', 'https://')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    
    const egressClient = new EgressClient(livekitUrl, apiKey, apiSecret)

    if (action === 'start') {
      const filename = `rec_${sessionId}_${Date.now()}.mp4`
      const filepath = `recordings/${sessionId}/${filename}`
      
      let publicDomain = Deno.env.get('R2_PUBLIC_DOMAIN') || ''
      if (publicDomain.endsWith('/')) publicDomain = publicDomain.slice(0, -1)
      const publicUrl = `${publicDomain}/${filepath}`

      // رابط صفحة القالب التي سنقوم بإنشائها
      const templateUrl = `https://learning-system-jet.vercel.app/recording-template.html?title=${encodeURIComponent(title || 'حصة تعليمية')}`

      console.log(`[REC] Starting Custom Layout Recording for: ${roomName}`)

      try {
        const info = await egressClient.startRoomCompositeEgress(
          roomName,
          {
            file: {
              fileType: EncodedFileType.MP4,
              filepath: filepath,
              s3: {
                endpoint: Deno.env.get('R2_ENDPOINT')!,
                bucket: Deno.env.get('R2_BUCKET')!,
                accessKey: Deno.env.get('R2_ACCESS_KEY')!,
                secret: Deno.env.get('R2_SECRET_KEY')!,
                forcePathStyle: true,
              },
            },
          },
          {
            // استخدام الرابط المخصص بدلاً من الأشكال الجاهزة
            customLayout: templateUrl,
            encodingOptions: {
              preset: 2, // H264_1080P_30
            }
          }
        )

        console.log(`[REC] Egress started successfully: ${info.egressId}`)

        await supabase.from('recordings').insert({
          session_id: sessionId,
          egress_id: info.egressId,
          file_path: filepath,
          video_url: publicUrl,
          status: 'recording',
          room_name: roomName
        })

        await supabase.from('sessions').update({ is_recording: true }).eq('id', sessionId)

        return new Response(JSON.stringify({ success: true, egressId: info.egressId }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        })
      } catch (err) {
        console.error(`[REC] SDK Error: ${err.message}`)
        throw err
      }
    }

    if (action === 'stop') {
      const active = await egressClient.listEgress({ roomName, active: true })
      if (active.length > 0) {
        await egressClient.stopEgress(active[0].egressId)
        await supabase.from('recordings').update({ status: 'processing' }).eq('egress_id', active[0].egressId)
      }
      await supabase.from('sessions').update({ is_recording: false }).eq('id', sessionId)
      return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    return new Response(JSON.stringify({ error: 'Invalid action' }), { status: 400 })

  } catch (error) {
    console.error(`[REC] Critical Error: ${error.message}`)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
