import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

console.log("Reminder Function Booted - Function is starting up...")

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

async function runReminderCheck() {
  const now = new Date()
  console.log(`Checking sessions at: ${now.toISOString()}`)

  try {
    // البحث عن الحصص التي تبدأ خلال الـ 20 دقيقة القادمة
    const targetTimeStart = new Date(now.getTime() + 5 * 60000)
    const targetTimeEnd = new Date(now.getTime() + 25 * 60000)

    console.log(`Searching sessions between ${targetTimeStart.toISOString()} and ${targetTimeEnd.toISOString()}`)

    const { data: sessions, error } = await supabase
      .from('sessions')
      .select(`
        id, 
        subject_name, 
        start_time,
        enrollments (
          profiles (
            phone_number,
            full_name
          )
        )
      `)
      .gte('start_time', targetTimeStart.toISOString())
      .lt('start_time', targetTimeEnd.toISOString())

    if (error) throw error
    
    if (!sessions || sessions.length === 0) {
      console.log("No sessions found in this window.")
      return "No sessions found."
    }

    console.log(`Found ${sessions.length} session(s) to notify.`)

    for (const session of sessions) {
      const enrollments = session.enrollments as any[]
      for (const enrollment of enrollments) {
        const student = enrollment.profiles
        if (student && student.phone_number) {
          const message = `تذكير: حصة ${session.subject_name} ستبدأ قريباً. استعد!`
          console.log(`Attempting to send notification to ${student.full_name} (${student.phone_number})`)

          await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/notify-whatsapp`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${Deno.env.get('SUPABASE_ANON_KEY')}`
            },
            body: JSON.stringify({
              phone: student.phone_number,
              message: message
            })
          })
        }
      }
    }
    return "Check completed successfully."
  } catch (err) {
    console.error("Error in reminder check:", err)
    return `Error: ${err.message}`
  }
}

// 1. للتشغيل المجدول (كل دقيقة)
// ملاحظة: Deno.cron قد لا تعمل في البيئات المحلية، ولكنها تعمل في سحابة Supabase
try {
  // @ts-ignore: Deno.cron might not be available in all types
  Deno.cron("Session Reminder Job", "* * * * *", async () => {
    await runReminderCheck()
  })
} catch (e) {
  console.log("Deno.cron is not supported in this environment, but the manual trigger via 'serve' will work.")
}

// 2. للتشغيل اليدوي (عند طلب الرابط)
serve(async (req) => {
  const result = await runReminderCheck()
  return new Response(JSON.stringify({ message: result }), { 
    headers: { "Content-Type": "application/json" } 
  })
})
