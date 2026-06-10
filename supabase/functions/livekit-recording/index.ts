import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { EgressClient, EncodedFileType, AccessToken } from "https://esm.sh/livekit-server-sdk@1.2.7"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { action, roomName, sessionId, title } = await req.json()

    const apiKey = Deno.env.get('LIVEKIT_API_KEY')
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')
    let livekitUrl = Deno.env.get('LIVEKIT_URL')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')

    if (!apiKey || !apiSecret || !livekitUrl) throw new Error('Missing LiveKit Secrets')
    if (livekitUrl.startsWith('wss://')) livekitUrl = livekitUrl.replace('wss://', 'https://')

    const egressClient = new EgressClient(livekitUrl, apiKey, apiSecret)
    const supabase = createClient(supabaseUrl!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    // --- 1. إجراء الـ Cleanup الجذري (قبل البدء أو عند الطلب) ---
    const cleanupOrphanEgresses = async () => {
      try {
        const activeEgresses = await egressClient.listEgress({ roomName, active: true })
        for (const e of activeEgresses) {
          await egressClient.stopEgress(e.egressId)
          console.log(`[RADICAL CLEANUP] Stopped orphan egress for ${roomName}: ${e.egressId}`)
        }
      } catch (e) {
        console.error('Cleanup failed:', e.message)
      }
    }

    if (action === 'start') {
      // تنظيف أي زبالة قديمة قبل ما نبدأ جديد
      await cleanupOrphanEgresses()

      const filename = `rec_${sessionId}_${Date.now()}.mp4`
      const filepath = `recordings/${sessionId}/${filename}`
      
      const at = new AccessToken(apiKey, apiSecret, { identity: `recorder_${Date.now()}`, name: 'Recording Bot' })
      at.addGrant({ roomJoin: true, room: roomName, canSubscribe: true, canPublish: false, canPublishData: true })
      const recorderToken = at.toJwt()

      const publicDomain = Deno.env.get('R2_PUBLIC_DOMAIN')?.replace(/\/$/, '') || ''
      const finalVideoUrl = `${publicDomain}/${filepath}`

      const templateUrl = `https://learning-system-jet.vercel.app/recording-template.html?title=${encodeURIComponent(title || 'حصة تعليمية')}&access_token=${recorderToken}&room=${roomName}&sb_url=${encodeURIComponent(supabaseUrl!)}&sb_key=${encodeURIComponent(supabaseAnonKey!)}&session_id=${sessionId}`

      console.log(`[REC] Starting WebEgress: ${templateUrl}`)

      const info = await egressClient.startWebEgress(
        templateUrl,
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
        }
      )

      await supabase.from('recordings').insert({
        session_id: sessionId, 
        egress_id: info.egressId, 
        file_path: filepath, 
        video_url: finalVideoUrl, // الرابط النهائي للرفع وليس القالب
        status: 'recording', 
        room_name: roomName
      })
      await supabase.from('sessions').update({ is_recording: true }).eq('id', sessionId)

      return new Response(JSON.stringify({ success: true, egressId: info.egressId }), { headers: corsHeaders })
    }

    if (action === 'stop') {
      await cleanupOrphanEgresses()
      await supabase.from('recordings').update({ status: 'processing' }).eq('room_name', roomName).eq('status', 'recording')
      await supabase.from('sessions').update({ is_recording: false, is_recording_paused: false }).eq('id', sessionId)
      return new Response(JSON.stringify({ success: true }), { headers: corsHeaders })
    }

    return new Response(JSON.stringify({ error: 'Invalid action' }), { status: 400 })
  } catch (error) {
    console.error('Recording Error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), { headers: corsHeaders, status: 500 })
  }
})
