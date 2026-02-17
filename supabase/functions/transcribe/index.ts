import "@supabase/functions-js/edge-runtime.d.ts"

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { encode } from "https://deno.land/std@0.200.0/encoding/base64.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SECRET_KEY = Deno.env.get("SECRET_KEY")!;

serve(async (req) => {
  try {
    const { id, file_path } = await req.json();
    if (!id || !file_path) {
      return new Response("Missing id or file_path", { status: 400 });
    }

    // 更新状态：processing
    console.log("🚀 ~ id: ", id);
    await fetch(`${SUPABASE_URL}/rest/v1/transcripts?id=eq.${id}`, {
      method: "PATCH",
      headers: {
        "apikey": SUPABASE_SECRET_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ status: "processing" }),
    });

    // 拉取音频
    const audioUrl = `${SUPABASE_URL}/storage/v1/object/authenticated/audio/${file_path}`;
    console.log("🚀 ~ file_path: ", file_path);
    const audioResp = await fetch(audioUrl, {
      method: "GET",
      headers: {
        "apikey": SUPABASE_SECRET_KEY
      },
    });
    if (!audioResp.ok) {
      const errorText = await audioResp.text();
      console.error("Storage 响应详情:", errorText);
      throw new Error(`从 Storage 音频下载失败: ${audioResp.status} ${audioResp.statusText}`);
    }
    const arrayBuffer = await audioResp.arrayBuffer(); // 转为 ArrayBuffer
    const base64Audio = encode(arrayBuffer); // 转为 Base64

    // AI 转录 - 总请求大小（包括文件、文本提示、系统指令等）超过 20 MB 时，请务必使用 Files API
    // https://ai.google.dev/gemini-api/docs/audio?hl=zh-cn&_gl=1*1aswy4j*_up*MQ..*_ga*NjQzNjQzODY4LjE3NzExNzAzODg.*_ga_P1DBVKWT6V*czE3NzExNzAzODckbzEkZzAkdDE3NzExNzAzOTYkajUxJGwwJGgxMjYxNzg0Nzg4#upload-audio
    const modelName = "gemini-2.5-flash-lite";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${GEMINI_API_KEY}`;
    const payload = {
      contents: [
        {
          parts: [
            { text: "请转录这段音频，直接输出文字。" },
            {
              inline_data: {
                mime_type: "audio/mp4",
                data: base64Audio
              }
            }
          ]
        }
      ]
    };
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    const result = await response.json();
    if (!response.ok) {
      throw new Error("LLM 识别失败");
    }
    const transcript = result.candidates?.[0]?.content?.parts?.[0]?.text;
    console.log("🚀 ~ transcript: ", transcript);

    // 写回数据库
    await fetch(`${SUPABASE_URL}/rest/v1/transcripts?id=eq.${id}`, {
      method: "PATCH",
      headers: {
        "apikey": SUPABASE_SECRET_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        status: "done",
        text: transcript,
      }),
    });

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    await fetch(`${SUPABASE_URL}/rest/v1/transcripts?id=eq.${id}`, {
      method: "PATCH",
      headers: {
        "apikey": SUPABASE_SECRET_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ error: String(e) }),
    });

    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
})