import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { EgressClient, EncodedFileOutput, EncodedFileType } from "https://esm.sh/livekit-server-sdk@1.2.7"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { action, roomName, sessionId } = await req.json()
    console.log(`[Recording] Action: ${action} | Room: ${roomName} | Session: ${sessionId}`)

    const apiKey = Deno.env.get('LIVEKIT_API_KEY')
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')
    const livekitUrl = Deno.env.get('LIVEKIT_URL')

    if (!apiKey || !apiSecret || !livekitUrl) {
      throw new Error('LIVEKIT_API_KEY or LIVEKIT_URL is missing in Supabase Secrets')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    
    const egressClient = new EgressClient(livekitUrl, apiKey, apiSecret)

    if (action === 'start') {
      const filename = `rec_${sessionId}_${Date.now()}.mp4`
      const filepath = `recordings/${sessionId}/${filename}`
      const publicUrl = `${Deno.env.get('R2_PUBLIC_DOMAIN')}/${filepath}`

      console.log(`Starting Composite Egress to: ${filepath}`)

      // إعدادات الـ S3 لـ Cloudflare R2
      const s3Output = {
        endpoint: Deno.env.get('R2_ENDPOINT')!,
        bucket: Deno.env.get('R2_BUCKET')!,
        accessKey: Deno.env.get('R2_ACCESS_KEY')!,
        secret: Deno.env.get('R2_SECRET_KEY')!,
        forcePathStyle: true,
      }

      const info = await egressClient.startRoomCompositeEgress(roomName, {
        file: {
          fileType: EncodedFileType.MP4,
          filepath: filepath,
          s3: s3Output,
        },
      })

      console.log(`Egress Started: ${info.egressId}`)

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
    console.error(`[CRITICAL ERROR]: ${error.message}`)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
