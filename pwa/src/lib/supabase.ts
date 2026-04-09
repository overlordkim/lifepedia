const SUPABASE_URL = 'https://okoeauotvsgjwhydfgsk.supabase.co'
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9rb2VhdW90dnNnandoeWRmZ3NrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2Mzk4OTksImV4cCI6MjA5MTIxNTg5OX0.p5UDU3QJi7OIWOEL8Sp8Ky6Cm_j1bf9v8R1xRbN6Wgo'

const ARK_MODEL = 'doubao-seed-2-0-lite-260215'
const SEEDREAM_MODEL = 'doubao-seedream-5-0-260128'

export { SUPABASE_URL, SUPABASE_ANON_KEY, ARK_MODEL, SEEDREAM_MODEL }

const headers = () => ({
  'apikey': SUPABASE_ANON_KEY,
  'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
  'Content-Type': 'application/json',
})

export const restURL = `${SUPABASE_URL}/rest/v1`
export const storageURL = `${SUPABASE_URL}/storage/v1`
export const functionsURL = `${SUPABASE_URL}/functions/v1`

export function avatarURL(userId: string): string {
  return `${SUPABASE_URL}/storage/v1/object/public/images/avatars/${userId}.jpg`
}

export async function supabaseGet<T>(path: string): Promise<T> {
  const res = await fetch(`${restURL}/${path}`, { headers: headers() })
  if (!res.ok) throw new Error(`Supabase GET 失败: ${res.status} ${await res.text()}`)
  return res.json()
}

export async function supabasePost<T>(path: string, body: unknown, extraHeaders?: Record<string, string>): Promise<T> {
  const res = await fetch(`${restURL}/${path}`, {
    method: 'POST',
    headers: { ...headers(), 'Prefer': 'return=representation', ...extraHeaders },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`Supabase POST 失败: ${res.status} ${await res.text()}`)
  return res.json()
}

export async function supabasePatch(path: string, body: unknown): Promise<void> {
  const res = await fetch(`${restURL}/${path}`, {
    method: 'PATCH',
    headers: { ...headers(), 'Prefer': 'return=minimal' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`Supabase PATCH 失败: ${res.status} ${await res.text()}`)
}

export async function supabaseDelete(path: string): Promise<void> {
  const res = await fetch(`${restURL}/${path}`, {
    method: 'DELETE',
    headers: headers(),
  })
  if (!res.ok) throw new Error(`Supabase DELETE 失败: ${res.status} ${await res.text()}`)
}

export async function uploadImage(data: Blob, fileName?: string): Promise<string> {
  const name = fileName ?? `${crypto.randomUUID()}.jpg`
  const path = `entries/${name}`
  const res = await fetch(`${storageURL}/object/images/${path}`, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Content-Type': 'image/jpeg',
      'x-upsert': 'true',
    },
    body: data,
  })
  if (!res.ok) throw new Error(`Storage 上传失败: ${res.status}`)
  return `${SUPABASE_URL}/storage/v1/object/public/images/${path}`
}

export async function callEdgeFunction<T>(fnName: string, body: unknown): Promise<T> {
  const res = await fetch(`${functionsURL}/${fnName}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`Edge Function ${fnName} 失败: ${res.status} ${await res.text()}`)
  return res.json()
}
