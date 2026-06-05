import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { EgressClient, EncodedFileOutput, EncodedFileType, S3Upload } from "https://esm.sh/livekit-server-sdk@1.2.7"
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
    const { action, roomName, sessionId } = await req.json()

    // 1. جلب الإعدادات من البيئة
    const apiKey = Deno.env.get('LIVEKIT_API_KEY')
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')
    const livekitUrl = Deno.env.get('LIVEKIT_URL')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!apiKey || !apiSecret || !livekitUrl || !supabaseUrl || !supabaseKey) {
      throw new Error('Required configuration missing in environment variables')
    }

    const supabase = createClient(supabaseUrl, supabaseKey)
    const egressClient = new EgressClient(livekitUrl, apiKey, apiSecret)

    if (action === 'start') {
      // 2. إعدادات Cloudflare R2
      const s3Upload = new S3Upload({
        endpoint: Deno.env.get('R2_ENDPOINT')!,
        bucket: Deno.env.get('R2_BUCKET')!,
        accessKey: Deno.env.get('R2_ACCESS_KEY')!,
        secret: Deno.env.get('R2_SECRET_KEY')!,
        forcePathStyle: true,
      })

      const filename = `${roomName}_${Date.now()}.mp4`
      const filepath = `recordings/${sessionId}/${filename}`
      
      // الرابط العام للفيديو (بعد ربط Domain بـ R2)
      const publicUrl = `${Deno.env.get('R2_PUBLIC_DOMAIN')}/${filepath}`

      const fileOutput = new EncodedFileOutput({
        fileType: EncodedFileType.MP4,
        filepath: filepath,
        s3: s3Upload,
      })

      // 3. بدء تسجيل الغرفة
      const info = await egressClient.startRoomCompositeEgress(roomName, {
        file: fileOutput,
      })

      // 4. حفظ بيانات التسجيل في قاعدة البيانات
      await supabase.from('recordings').insert({
        session_id: sessionId,
        egress_id: info.egressId,
        file_path: filepath,
        video_url: publicUrl,
        status: 'recording',
        room_name: roomName
      })

      return new Response(JSON.stringify({ egressId: info.egressId, filepath, publicUrl }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    if (action === 'stop') {
      // البحث عن التسجيل النشط
      const activeEgresses = await egressClient.listEgress({ roomName, active: true })
      
      if (activeEgresses.length === 0) {
        return new Response(JSON.stringify({ error: 'No active recording found' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 404,
        })
      }

      const egressId = activeEgresses[0].egressId
      await egressClient.stopEgress(egressId)

      // 5. تحديث حالة السجل في الداتابيز
      await supabase.from('recordings')
        .update({ status: 'completed' })
        .eq('egress_id', egressId)

      return new Response(JSON.stringify({ message: 'Recording stopped', egressId }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    return new Response(JSON.stringify({ error: 'Invalid action' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
