import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }})
  }

  try {
    const { phone, message } = await req.json()

    const EVOLUTION_URL = Deno.env.get('EVOLUTION_API_URL')
    
    // إذا لم تكن الإعدادات موجودة، سنعتبرنا في وضع التجربة
    if (!EVOLUTION_URL) {
      console.log("🛠️ [DEV MODE] WhatsApp Message Simulated:");
      console.log(`To: ${phone}`);
      console.log(`Message: ${message}`);
      
      return new Response(JSON.stringify({ 
        success: true, 
        message: "Simulated successfully in dev mode" 
      }), {
        status: 200,
        headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' }
      })
    }

    // الكود الحقيقي (سيعمل فقط إذا وضعت الـ Secrets لاحقاً)
    const API_KEY = Deno.env.get('EVOLUTION_API_KEY')
    const INSTANCE = Deno.env.get('EVOLUTION_INSTANCE_NAME')
    const cleanPhone = phone.replace(/\D/g, '')

    const response = await fetch(`${EVOLUTION_URL}/message/sendText/${INSTANCE}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'apikey': API_KEY! },
      body: JSON.stringify({
        number: cleanPhone,
        textMessage: { text: message }
      })
    })

    const result = await response.json()
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' }
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' }
    })
  }
})
