import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { AccessToken } from "https://esm.sh/livekit-server-sdk@1.2.7"

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }})
  }

  try {
    const { roomName, userId, userName, isRoomCamera } = await req.json()

    const apiKey = Deno.env.get('LIVEKIT_API_KEY')
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')

    if (!apiKey || !apiSecret) {
      throw new Error("LiveKit API Key or Secret not set")
    }

    const identity = isRoomCamera ? `roomcam_${userId}` : userId.toString()

    const at = new AccessToken(apiKey, apiSecret, {
      identity: identity,
      name: userName,
    })

    if (isRoomCamera) {
      at.addGrant({ 
        roomJoin: true, 
        room: roomName, 
        canPublish: true, 
        canSubscribe: false,
        canPublishData: false
      })
    } else {
      at.addGrant({ 
        roomJoin: true, 
        room: roomName, 
        canPublish: true, 
        canSubscribe: true,
        canPublishData: true 
      })
    }

    return new Response(
      JSON.stringify({ token: at.toJwt() }),
      { 
        headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' },
        status: 200 
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' }, status: 400 }
    )
  }
})
