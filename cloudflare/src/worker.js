const FIREBASE_CERTS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const GROQ_CHAT_URL = 'https://api.groq.com/openai/v1/chat/completions';
const MAX_MESSAGES = 12;
const MAX_MESSAGE_LENGTH = 1800;
const MAX_TOTAL_LENGTH = 7000;

let cachedJwks;
let cachedJwksUntil = 0;

function json(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type',
      ...extraHeaders,
    },
  });
}

function decodeBase64Url(value) {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

function decodeJsonPart(value) {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(value)));
}

async function getFirebaseJwks(forceRefresh = false) {
  if (!forceRefresh && cachedJwks && Date.now() < cachedJwksUntil) {
    return cachedJwks;
  }
  const response = await fetch(FIREBASE_CERTS_URL, {
    cf: { cacheTtl: 1800, cacheEverything: true },
  });
  if (!response.ok) throw new Error('Could not load Firebase signing keys.');
  const data = await response.json();
  cachedJwks = Array.isArray(data.keys) ? data.keys : [];
  cachedJwksUntil = Date.now() + 30 * 60 * 1000;
  return cachedJwks;
}

async function verifyFirebaseToken(token, projectId) {
  const parts = token.split('.');
  if (parts.length !== 3) return false;
  let header;
  let payload;
  try {
    header = decodeJsonPart(parts[0]);
    payload = decodeJsonPart(parts[1]);
  } catch (_) {
    return false;
  }
  if (header.alg !== 'RS256' || typeof header.kid !== 'string') return false;

  let keys = await getFirebaseJwks();
  let signingKey = keys.find((key) => key.kid === header.kid);
  if (!signingKey) {
    keys = await getFirebaseJwks(true);
    signingKey = keys.find((key) => key.kid === header.kid);
  }
  if (!signingKey) return false;

  const now = Math.floor(Date.now() / 1000);
  if (
    payload.aud !== projectId ||
    payload.iss !== `https://securetoken.google.com/${projectId}` ||
    typeof payload.sub !== 'string' ||
    payload.sub.length === 0 ||
    typeof payload.exp !== 'number' ||
    payload.exp <= now ||
    typeof payload.iat !== 'number' ||
    payload.iat > now + 60
  ) {
    return false;
  }

  try {
    const publicKey = await crypto.subtle.importKey(
      'jwk',
      signingKey,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify'],
    );
    const data = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
    const validSignature = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      publicKey,
      decodeBase64Url(parts[2]),
      data,
    );
    return validSignature ? payload.sub : false;
  } catch (_) {
    return false;
  }
}

function validateMessages(messages) {
  if (!Array.isArray(messages) || messages.length < 1 || messages.length > MAX_MESSAGES) {
    return false;
  }
  let totalLength = 0;
  for (const message of messages) {
    if (
      !message ||
      !['user', 'assistant'].includes(message.role) ||
      typeof message.content !== 'string'
    ) {
      return false;
    }
    const content = message.content.trim();
    if (!content || content.length > MAX_MESSAGE_LENGTH) return false;
    totalLength += content.length;
  }
  return totalLength <= MAX_TOTAL_LENGTH && messages.at(-1).role === 'user';
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return json({ ok: true });
    if (request.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);
    if (!env.GROQ_API_KEY) return json({ error: 'SafeBot belum dikonfigurasi.' }, 503);

    const authorization = request.headers.get('Authorization') || '';
    const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);
    if (!tokenMatch) return json({ error: 'Silakan login untuk memakai SafeBot.' }, 401);

    let authenticatedUid;
    try {
      authenticatedUid = await verifyFirebaseToken(tokenMatch[1], env.FIREBASE_PROJECT_ID);
    } catch (_) {
      return json({ error: 'Tidak dapat memeriksa sesi login. Coba lagi.' }, 503);
    }
    if (!authenticatedUid) return json({ error: 'Sesi login tidak valid. Silakan login ulang.' }, 401);

    const contentLength = Number(request.headers.get('Content-Length') || 0);
    if (contentLength > 32 * 1024) {
      return json({ error: 'Pesan terlalu besar.' }, 413);
    }

    let body;
    try {
      body = await request.json();
    } catch (_) {
      return json({ error: 'Format permintaan tidak valid.' }, 400);
    }
    if (!validateMessages(body?.messages)) {
      return json({ error: 'Pesan terlalu panjang atau formatnya tidak valid.' }, 400);
    }

    // Throttle valid requests before they can consume Groq tokens. Cloudflare's
    // edge counters are approximate per location; account IDs are safer than IPs.
    if (!env.CHAT_USER_LIMITER || !env.CHAT_TOTAL_LIMITER) {
      return json({ error: 'Pembatas SafeBot belum dikonfigurasi.' }, 503);
    }
    const accountLimit = await env.CHAT_USER_LIMITER.limit({ key: `uid:${authenticatedUid}` });
    if (!accountLimit.success) {
      return json(
        { error: 'Kamu mencapai batas 5 pesan per menit. Tunggu sebentar lalu coba lagi.' },
        429,
        { 'Retry-After': '60' },
      );
    }
    const serviceLimit = await env.CHAT_TOTAL_LIMITER.limit({ key: 'safezone-chatbot' });
    if (!serviceLimit.success) {
      return json(
        { error: 'SafeBot sedang ramai. Coba lagi sebentar.' },
        429,
        { 'Retry-After': '60' },
      );
    }

    let groqResponse;
    try {
      groqResponse = await fetch(GROQ_CHAT_URL, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.GROQ_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'qwen/qwen3.8-27b',
          messages: [
            {
              role: 'system',
              content:
                'Kamu adalah SafeBot, asisten aplikasi SafeZone Indonesia. Kamu menggunakan model Qwen 3.8 27B yang dijalankan melalui Groq. Jika pengguna bertanya model atau siapa kamu, jawab dengan jujur: "Aku SafeBot, menggunakan Qwen melalui Groq; aku bukan GPT-4." Jangan pernah mengaku GPT-4, ChatGPT, atau model OpenAI. Jawab dalam bahasa Indonesia yang santai, jelas, dan ringkas. Format jawaban agar nyaman dibaca di layar ponsel: gunakan paragraf pendek; untuk panduan gunakan nomor seperti 1. dan poin dengan simbol •; beri jarak antarbagian. Jangan gunakan Markdown, tanda bintang/asterisk, backticks, atau heading bertanda pagar; jangan membungkus judul dengan simbol. Bantu pengguna memahami fitur SafeZone seperti laporan warga, voting, SOS, peta, lokasi, Safe Friend, QR, akun, dan notifikasi. Jangan mengaku dapat melihat akun, lokasi langsung, atau data laporan pengguna. Jangan menyatakan bahwa suatu tempat atau rute pasti aman. Dalam keadaan darurat, arahkan pengguna menghubungi layanan darurat setempat; kamu bukan petugas darurat dan tidak dapat mengirim bantuan. Jangan meminta password, kode OTP, atau data pribadi sensitif. Jika tidak yakin dengan langkah khusus aplikasi, katakan terus terang dan berikan panduan umum yang aman.',
            },
            ...body.messages,
          ],
          max_completion_tokens: 450,
          temperature: 0.5,
        }),
      });
    } catch (_) {
      return json({ error: 'SafeBot AI sedang tidak bisa dijangkau.' }, 503);
    }

    if (groqResponse.status === 429) {
      return json({ error: 'Batas gratis AI sedang tercapai. Coba lagi nanti.' }, 429);
    }
    if (!groqResponse.ok) {
      return json({ error: 'SafeBot AI sedang mengalami gangguan.' }, 503);
    }

    const result = await groqResponse.json();
    const reply = result?.choices?.[0]?.message?.content;
    if (typeof reply !== 'string' || !reply.trim()) {
      return json({ error: 'SafeBot belum mendapat jawaban.' }, 502);
    }
    return json({ reply: reply.trim() });
  },
};
