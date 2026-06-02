import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { EgressClient, EncodedFileOutput, EncodedFileType, S3Upload } from "https://esm.sh/livekit-server-sdk@1.2.7"

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

    const apiKey = Deno.env.get('LIVEKIT_API_KEY')
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')
    const livekitUrl = Deno.env.get('LIVEKIT_URL')

    if (!apiKey || !apiSecret || !livekitUrl) {
      throw new Error('LiveKit configuration missing')
    }

    const egressClient = new EgressClient(livekitUrl, apiKey, apiSecret)

    if (action === 'start') {
      // إعدادات Cloudflare R2 (S3 Compatible)
      const s3Upload = new S3Upload({
        endpoint: Deno.env.get('R2_ENDPOINT'), // مثال: https://<id>.r2.cloudflarestorage.com
        bucket: Deno.env.get('R2_BUCKET'),
        accessKey: Deno.env.get('R2_ACCESS_KEY'),
        secret: Deno.env.get('R2_SECRET_KEY'),
        forcePathStyle: true,
      })

      const filepath = `recordings/${sessionId}/${roomName}_${Date.now()}.mp4`

      const fileOutput = new EncodedFileOutput({
        fileType: EncodedFileType.MP4,
        filepath: filepath,
        s3: s3Upload,
      })

      // بدء تسجيل القاعة بالكامل (Composite Recording)
      const info = await egressClient.startRoomCompositeEgress(roomName, {
        file: fileOutput,
      })

      return new Response(JSON.stringify({ egressId: info.egressId, filepath }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    if (action === 'stop') {
      // نحتاج لإرسال الـ egressId لإيقافه، أو البحث عنه باسم الغرفة
      // في هذا المثال البسيط سنقوم بجلب قائمة الـ Egress النشطة للغرفة
      const activeEgresses = await egressClient.listEgress({ roomName, active: true })
      
      if (activeEgresses.length === 0) {
        return new Response(JSON.stringify({ message: 'No active recording found' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 404,
        })
      }

      const egressId = activeEgresses[0].egressId
      await egressClient.stopEgress(egressId)

      return new Response(JSON.stringify({ message: 'Recording stopped', egressId }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // منطق الـ Pause والـ Resume
    // ملاحظة: LiveKit Egress لا يدعم "الإيقاف المؤقت" داخل نفس الملف بشكل مباشر حالياً
    // البديل الاحترافي هو التحكم في الـ Layout أو استخدام منطق الـ Webhook
    if (action === 'pause' || action === 'resume') {
      return new Response(JSON.stringify({ message: 'Action supported via UI state only for now' }), {
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
