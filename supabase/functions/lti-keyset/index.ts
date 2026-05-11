import { serve } from "https://deno.land/std@0.177.0/http/server.ts"

serve(async (req) => {
  const jwks = {
    "keys": [
      {
        "kty": "RSA",
        "n": "xTo2Uya8fKekGnQ4Jjx4RyLOZMvb0XWs07PdERF3l21rr032a3GxQzS4-3Z9585A02gyNb4Isf2jS2x4CnAr3LfF5Bm2AAAwTRpstMoZBsVs1N1lrZNPl2sHq2hGNPSG2s6X5S5XA-A5fWQFujrIL1Bir5hwkZaiEfR1NbqaD0EO7QuzjhwAcc3EDL9SLH6kamGyYMdjU0f1ioD7GQRJkB436YiUqyWSCDisvYlqAN8qWYSDe3pOKKk1HdDfLyMgojOPewBY1fZWnM3H13_3m8x2j4JUz4ysK9KL-zt2LomInO9Q0lez7cCxXic-lw_szJNoe35AaXgPXsA79L5cQ",
        "e": "AQAB",
        "alg": "RS256",
        "use": "sig",
        "kid": "edu-connect-key-1"
      }
    ]
  };

  return new Response(JSON.stringify(jwks), {
    headers: { 
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*" 
    },
  })
})
