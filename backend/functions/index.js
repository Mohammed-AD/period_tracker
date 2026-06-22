/**
 * Firebase Cloud Functions — Gemini Chat Proxy + Forgot-PIN Email OTP
 * ---------------------------------------------------------------------
 * This is the ONLY place your Gemini API key and Resend API key should
 * ever live. The Flutter app calls these functions over HTTPS; the
 * functions call Gemini / Resend and return only what the app needs.
 *
 * Deploy with: firebase deploy --only functions
 * See ../../README_SETUP.md for full setup steps.
 */

const functions = require("firebase-functions");
const fetch = require("node-fetch");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

// Store your key with: firebase functions:config:set gemini.key="YOUR_KEY"
// Then access it below. (Or use Firebase Secrets — see README.)
const GEMINI_API_KEY = functions.config().gemini.key;
const GEMINI_MODEL = "gemini-2.5-flash"; // free-tier model, generous daily limit
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

const SYSTEM_PROMPT = `You are a warm, knowledgeable menstrual health assistant inside a period-tracking app called Bloom.
Rules:
- Keep answers concise (2-4 sentences) and conversational, like a knowledgeable friend.
- You can discuss period symptoms, cycle predictions, general reproductive health education.
- You are NOT a doctor. For anything that sounds like a medical emergency, unusual pain, or a request for diagnosis, gently recommend seeing a doctor.
- Never make a definitive medical diagnosis.
- Be supportive and non-judgmental.
- Use the provided cycle context (average cycle length, last period date, recent symptoms) to personalize answers when relevant.`;

exports.chatProxy = functions.https.onRequest(async (req, res) => {
  // CORS for app requests
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const { message, context } = req.body;

    if (!message || typeof message !== "string") {
      res.status(400).json({ error: "Missing 'message' field" });
      return;
    }

    const contextStr = context
      ? `User's cycle context: average cycle length ${context.averageCycleLength || "unknown"} days, ` +
        `average period length ${context.averagePeriodLength || "unknown"} days, ` +
        `last period started ${context.lastPeriodStart || "unknown"}, ` +
        `recent symptoms: ${(context.recentSymptoms || []).join(", ") || "none logged"}.`
      : "";

    const geminiResponse = await fetch(GEMINI_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [{ text: `${SYSTEM_PROMPT}\n\n${contextStr}\n\nUser question: ${message}` }],
          },
        ],
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 300,
        },
      }),
    });

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text();
      console.error("Gemini API error:", errText);
      res.status(502).json({ error: "AI service error" });
      return;
    }

    const data = await geminiResponse.json();
    const reply =
      data?.candidates?.[0]?.content?.parts?.[0]?.text ||
      "Sorry, I couldn't generate a response. Please try again.";

    res.status(200).json({ reply });
  } catch (err) {
    console.error("chatProxy error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * Forgot-PIN Email OTP
 * ---------------------
 * Flow:
 *  1. App calls /sendOtp with { email } -> we generate a 6-digit code,
 *     store its HASH (not the raw code) + expiry in Firestore keyed by
 *     email, and send the raw code to that email address via Resend.
 *  2. App calls /verifyOtp with { email, otp } -> we hash the submitted
 *     code and compare. On match we return a short-lived reset token
 *     the app must send back when it actually changes the PIN
 *     (prevents a captured "otp" from being replayed after the PIN
 *     change already used it once).
 *  3. App calls /confirmReset with { email, resetToken } right before
 *     locally saving the new PIN, purely to invalidate the token so it
 *     can't be reused. The PIN itself is never sent to or stored on
 *     the server — it stays 100% on-device, exactly like before.
 *
 * Store your Resend key with:
 *   firebase functions:secrets:set RESEND_API_KEY
 */
const RESEND_FROM_ADDRESS = "Bloom <onboarding@resend.dev>"; // see README to use your own verified domain
const OTP_TTL_MINUTES = 5;
const OTP_MAX_ATTEMPTS = 5;
const RESET_TOKEN_TTL_MINUTES = 10;

function hashCode(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

function isValidEmail(email) {
  return typeof email === "string" && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

exports.sendOtp = functions
  .runWith({ secrets: ["RESEND_API_KEY"] })
  .https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "POST");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      const { email } = req.body;
      if (!isValidEmail(email)) {
        res.status(400).json({ error: "Valid email is required" });
        return;
      }
      const normalizedEmail = email.trim().toLowerCase();

      // Basic rate limit: don't allow a resend within 30 seconds of the
      // previous one for the same email, so the function can't be used
      // to spam someone's inbox.
      const docRef = db.collection("password_reset_otps").doc(normalizedEmail);
      const existing = await docRef.get();
      if (existing.exists) {
        const data = existing.data();
        const createdAtMs = data.createdAt && data.createdAt.toMillis ? data.createdAt.toMillis() : 0;
        if (Date.now() - createdAtMs < 30 * 1000) {
          res.status(429).json({ error: "Please wait before requesting another code" });
          return;
        }
      }

      const otp = String(crypto.randomInt(0, 1000000)).padStart(6, "0");
      const expiresAt = admin.firestore.Timestamp.fromMillis(
        Date.now() + OTP_TTL_MINUTES * 60 * 1000
      );

      await docRef.set({
        otpHash: hashCode(otp),
        expiresAt,
        attempts: 0,
        verified: false,
        createdAt: admin.firestore.Timestamp.now(),
      });

      const resendResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        },
        body: JSON.stringify({
          from: RESEND_FROM_ADDRESS,
          to: [normalizedEmail],
          subject: "Your Bloom PIN reset code",
          html:
            `<p>Your one-time code to reset your Bloom app PIN is:</p>` +
            `<h2 style="letter-spacing:4px;">${otp}</h2>` +
            `<p>This code expires in ${OTP_TTL_MINUTES} minutes. If you didn't request this, you can ignore this email.</p>`,
        }),
      });

      if (!resendResponse.ok) {
        const errText = await resendResponse.text();
        console.error("Resend error:", errText);
        res.status(502).json({ error: "Could not send email" });
        return;
      }

      res.status(200).json({ sent: true });
    } catch (err) {
      console.error("sendOtp error:", err);
      res.status(500).json({ error: "Internal server error" });
    }
  });

exports.verifyOtp = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return;
  }
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const { email, otp } = req.body;
    if (!isValidEmail(email) || typeof otp !== "string" || otp.length !== 6) {
      res.status(400).json({ error: "Valid email and 6-digit code are required" });
      return;
    }
    const normalizedEmail = email.trim().toLowerCase();

    const docRef = db.collection("password_reset_otps").doc(normalizedEmail);
    const snap = await docRef.get();
    if (!snap.exists) {
      res.status(400).json({ error: "No code requested for this email" });
      return;
    }

    const data = snap.data();
    if (data.expiresAt.toMillis() < Date.now()) {
      await docRef.delete();
      res.status(400).json({ error: "Code expired — request a new one" });
      return;
    }
    if (data.attempts >= OTP_MAX_ATTEMPTS) {
      await docRef.delete();
      res.status(429).json({ error: "Too many attempts — request a new code" });
      return;
    }

    if (data.otpHash !== hashCode(otp)) {
      await docRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
      res.status(400).json({ error: "Incorrect code" });
      return;
    }

    // Correct code: issue a one-time reset token, delete the OTP itself
    // so it can't be reused, and let the app proceed to set a new PIN.
    const resetToken = crypto.randomBytes(24).toString("hex");
    await docRef.delete();
    await db.collection("password_reset_tokens").doc(normalizedEmail).set({
      tokenHash: hashCode(resetToken),
      expiresAt: admin.firestore.Timestamp.fromMillis(
        Date.now() + RESET_TOKEN_TTL_MINUTES * 60 * 1000
      ),
      used: false,
    });

    res.status(200).json({ verified: true, resetToken });
  } catch (err) {
    console.error("verifyOtp error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

exports.confirmReset = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return;
  }
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const { email, resetToken } = req.body;
    if (!isValidEmail(email) || typeof resetToken !== "string") {
      res.status(400).json({ error: "Valid email and resetToken are required" });
      return;
    }
    const normalizedEmail = email.trim().toLowerCase();

    const docRef = db.collection("password_reset_tokens").doc(normalizedEmail);
    const snap = await docRef.get();
    if (!snap.exists) {
      res.status(400).json({ error: "Reset session not found or already used" });
      return;
    }
    const data = snap.data();
    if (data.used || data.expiresAt.toMillis() < Date.now() || data.tokenHash !== hashCode(resetToken)) {
      await docRef.delete();
      res.status(400).json({ error: "Reset session invalid or expired — start over" });
      return;
    }

    await docRef.delete(); // one-time use
    res.status(200).json({ confirmed: true });
  } catch (err) {
    console.error("confirmReset error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});
