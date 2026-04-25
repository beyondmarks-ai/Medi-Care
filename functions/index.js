const admin = require("firebase-admin");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {AccessToken} = require("livekit-server-sdk");

admin.initializeApp();

const OPENROUTER_API_KEY = defineSecret("OPENROUTER_API_KEY");
const SARVAM_API_KEY = defineSecret("SARVAM_API_KEY");
const LIVEKIT_URL = defineSecret("LIVEKIT_URL");
const LIVEKIT_API_KEY = defineSecret("LIVEKIT_API_KEY");
const LIVEKIT_API_SECRET = defineSecret("LIVEKIT_API_SECRET");

const OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";
const OPENROUTER_MODEL = "openai/gpt-4.1-mini";
const SARVAM_ENDPOINT = "https://api.sarvam.ai/text-to-speech";
const SARVAM_MODEL = "bulbul:v3";
const SARVAM_SPEAKER = "shubh";

const SYSTEM_PROMPT = `
You are a professional medical assistant inside a healthcare app.

Strict rules:
- Answer ONLY medical and health-related queries.
- If a user asks anything non-medical (coding, finance, travel, jokes, etc.), politely refuse and ask them to ask a medical question.
- Never claim to be a doctor.
- Do not provide emergency diagnosis certainty.
- For emergencies (chest pain, breathing trouble, stroke signs, severe bleeding, suicidal intent, unconsciousness, seizures, severe allergic reactions), tell the user to contact local emergency services immediately.
- Keep answers concise, practical, and safe.
- If unsure, clearly say uncertainty and suggest consulting a licensed clinician.

Response style requirements:
- Sound professional and clinically clear, like a careful doctor.
- Use very simple words so non-medical users can understand.
- Keep responses short and concise (usually 4-8 bullets maximum).
- Always format in Markdown with clear sections:
  **Quick Answer**
  **Possible Causes**
  **What You Can Do Now**
  **When to Seek Urgent Care**
- Use bullet points for each section.
- Highlight critical warnings with **bold** text.
`;

function corsHeaders(origin = "*") {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function sendJson(res, status, payload, origin) {
  res.set(corsHeaders(origin));
  res.status(status).json(payload);
}

async function verifyBearerAuth(req) {
  const authHeader = req.get("Authorization") || "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new Error("missing-auth");
  }
  const token = match[1];
  const decoded = await admin.auth().verifyIdToken(token);
  return decoded;
}

function languageDirective(language) {
  switch (language) {
    case "Hindi":
      return "Hindi (Devanagari script)";
    case "Bengali":
      return "Bengali (Bangla script)";
    case "Telugu":
      return "Telugu (Telugu script)";
    case "Marathi":
      return "Marathi (Devanagari script)";
    case "Tamil":
      return "Tamil (Tamil script)";
    case "Urdu":
      return "Urdu (Perso-Arabic script)";
    case "Gujarati":
      return "Gujarati (Gujarati script)";
    case "Kannada":
      return "Kannada (Kannada script)";
    case "Odia":
      return "Odia (Odia script)";
    case "Malayalam":
      return "Malayalam (Malayalam script)";
    case "Punjabi":
      return "Punjabi (Gurmukhi script)";
    case "Assamese":
      return "Assamese (Assamese/Bengali script)";
    case "Maithili":
      return "Maithili (Devanagari script)";
    case "Santali":
      return "Santali (Ol Chiki script preferred)";
    case "Kashmiri":
      return "Kashmiri (Perso-Arabic script)";
    case "Nepali":
      return "Nepali (Devanagari script)";
    case "Konkani":
      return "Konkani (Devanagari script)";
    case "Sindhi":
      return "Sindhi (Perso-Arabic script)";
    case "Dogri":
      return "Dogri (Devanagari script)";
    case "Manipuri":
      return "Manipuri/Meitei (Meitei Mayek preferred)";
    case "Bodo":
      return "Bodo (Devanagari script)";
    case "Sanskrit":
      return "Sanskrit (Devanagari script)";
    case "English":
    default:
      return "English";
  }
}

function looksMostlyEnglish(text) {
  if (!text || !text.trim()) return false;
  const letters = (text.match(/[A-Za-z]/g) || []).length;
  const nonWhitespace = text.replace(/\s/g, "").length;
  if (nonWhitespace === 0) return false;
  return letters / nonWhitespace > 0.45;
}

function languageToSarvamCode(language) {
  switch (language) {
    case "Hindi":
      return "hi-IN";
    case "Bengali":
      return "bn-IN";
    case "Telugu":
      return "te-IN";
    case "Marathi":
      return "mr-IN";
    case "Tamil":
      return "ta-IN";
    case "Urdu":
      return "ur-IN";
    case "Gujarati":
      return "gu-IN";
    case "Kannada":
      return "kn-IN";
    case "Odia":
      return "od-IN";
    case "Malayalam":
      return "ml-IN";
    case "Punjabi":
      return "pa-IN";
    case "Assamese":
      return "as-IN";
    case "Maithili":
      return "mai-IN";
    case "Santali":
      return "sat-IN";
    case "Kashmiri":
      return "ks-IN";
    case "Nepali":
      return "ne-IN";
    case "Konkani":
      return "kok-IN";
    case "Sindhi":
      return "sd-IN";
    case "Dogri":
      return "doi-IN";
    case "Manipuri":
      return "mni-IN";
    case "Bodo":
      return "brx-IN";
    case "Sanskrit":
      return "sa-IN";
    case "English":
    default:
      return "en-IN";
  }
}

async function callOpenRouter({messages, temperature}) {
  const response = await fetch(OPENROUTER_ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENROUTER_API_KEY.value()}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://medicare-ai.local",
      "X-Title": "Medicare AI",
    },
    body: JSON.stringify({
      model: OPENROUTER_MODEL,
      messages,
      temperature,
    }),
  });
  const bodyText = await response.text();
  if (!response.ok) {
    throw new Error(`openrouter-failed:${response.status}:${bodyText}`);
  }
  const decoded = JSON.parse(bodyText);
  const content = decoded?.choices?.[0]?.message?.content;
  if (typeof content !== "string" || !content.trim()) {
    throw new Error("openrouter-empty");
  }
  return content.trim();
}

exports.openrouterChat = onRequest(
    {region: "us-central1", secrets: [OPENROUTER_API_KEY]},
    async (req, res) => {
      const origin = req.get("Origin") || "*";
      if (req.method === "OPTIONS") {
        return sendJson(res, 204, {}, origin);
      }
      if (req.method !== "POST") {
        return sendJson(res, 405, {error: "Method not allowed"}, origin);
      }
      try {
        await verifyBearerAuth(req);
        const history = Array.isArray(req.body?.history) ? req.body.history : [];
        const outputLanguage = (req.body?.outputLanguage || "English").toString();
        const directive = languageDirective(outputLanguage);
        const messages = [
          {role: "system", content: SYSTEM_PROMPT},
          {
            role: "system",
            content: `The user may ask in any language.
You MUST answer ONLY in: ${directive}.
Never answer in English unless the selected output language is English.
Keep medical meaning accurate while translating.`,
          },
          ...history.map((m) => ({
            role: (m?.role || "user").toString(),
            content: (m?.content || "").toString(),
          })),
        ];
        let text = await callOpenRouter({messages, temperature: 0.1});
        if (outputLanguage !== "English" && looksMostlyEnglish(text)) {
          const translated = await callOpenRouter({
            temperature: 0,
            messages: [
              {
                role: "system",
                content: "You are a strict medical translator. Translate faithfully and return only translated medical guidance with bullets preserved.",
              },
              {
                role: "user",
                content: `Translate the following medical response to ${directive}. Do not use English.\n\n${text}`,
              },
            ],
          });
          if (translated.trim()) text = translated.trim();
        }
        return sendJson(res, 200, {text}, origin);
      } catch (error) {
        return sendJson(res, 400, {error: error.message || "Request failed"}, origin);
      }
    },
);

exports.sarvamTts = onRequest(
    {region: "us-central1", secrets: [SARVAM_API_KEY]},
    async (req, res) => {
      const origin = req.get("Origin") || "*";
      if (req.method === "OPTIONS") {
        return sendJson(res, 204, {}, origin);
      }
      if (req.method !== "POST") {
        return sendJson(res, 405, {error: "Method not allowed"}, origin);
      }
      try {
        await verifyBearerAuth(req);
        const text = (req.body?.text || "").toString().trim();
        const language = (req.body?.language || "English").toString();
        if (!text) {
          return sendJson(res, 400, {error: "Text is required"}, origin);
        }
        const response = await fetch(SARVAM_ENDPOINT, {
          method: "POST",
          headers: {
            "api-subscription-key": SARVAM_API_KEY.value(),
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            text,
            model: SARVAM_MODEL,
            speaker: SARVAM_SPEAKER,
            target_language_code: languageToSarvamCode(language),
            speech_sample_rate: 24000,
            pace: 1.0,
          }),
        });
        const bodyText = await response.text();
        if (!response.ok) {
          throw new Error(`sarvam-failed:${response.status}:${bodyText}`);
        }
        const decoded = JSON.parse(bodyText);
        const audioBase64 = decoded?.audios?.[0];
        if (typeof audioBase64 !== "string" || !audioBase64.trim()) {
          throw new Error("sarvam-empty");
        }
        return sendJson(res, 200, {audioBase64}, origin);
      } catch (error) {
        return sendJson(res, 400, {error: error.message || "Request failed"}, origin);
      }
    },
);

exports.livekitToken = onRequest(
    {region: "us-central1", secrets: [LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET]},
    async (req, res) => {
      const origin = req.get("Origin") || "*";
      if (req.method === "OPTIONS") {
        return sendJson(res, 204, {}, origin);
      }
      if (req.method !== "POST") {
        return sendJson(res, 405, {error: "Method not allowed"}, origin);
      }
      try {
        await verifyBearerAuth(req);
        const roomName = (req.body?.roomName || "").toString().trim();
        const identity = (req.body?.identity || "").toString().trim();
        const participantName = (req.body?.participantName || "").toString().trim();
        if (!roomName || !identity || !participantName) {
          return sendJson(res, 400, {error: "roomName, identity, participantName are required"}, origin);
        }

        const token = new AccessToken(
            LIVEKIT_API_KEY.value(),
            LIVEKIT_API_SECRET.value(),
            {
              identity,
              name: participantName,
              ttl: "1h",
            },
        );
        token.addGrant({
          roomJoin: true,
          room: roomName,
          canPublish: true,
          canSubscribe: true,
        });
        return sendJson(res, 200, {
          serverUrl: LIVEKIT_URL.value(),
          token: await token.toJwt(),
        }, origin);
      } catch (error) {
        return sendJson(res, 400, {error: error.message || "Request failed"}, origin);
      }
    },
);
