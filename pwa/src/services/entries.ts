import { supabaseGet, supabaseDelete, uploadImage } from '../lib/supabase'
import { restURL, SUPABASE_ANON_KEY } from '../lib/supabase'
import type { SupabaseEntry } from '../types'

export async function fetchPublishedEntries(): Promise<SupabaseEntry[]> {
  return supabaseGet<SupabaseEntry[]>('entries?status=eq.published&order=created_at.desc&limit=200')
}

export async function fetchEntryById(id: string): Promise<SupabaseEntry | null> {
  const rows = await supabaseGet<SupabaseEntry[]>(`entries?id=eq.${id}&limit=1`)
  return rows[0] ?? null
}

export async function fetchEntriesByAuthor(authorId: string): Promise<SupabaseEntry[]> {
  return supabaseGet<SupabaseEntry[]>(
    `entries?author_id=eq.${encodeURIComponent(authorId)}&status=eq.published&order=created_at.desc`
  )
}

export async function fetchEntriesByContributor(name: string): Promise<SupabaseEntry[]> {
  return supabaseGet<SupabaseEntry[]>(
    `entries?contributor_names=cs.{${encodeURIComponent(name)}}&status=eq.published&order=created_at.desc`
  )
}

export async function upsertEntry(entry: SupabaseEntry): Promise<void> {
  const res = await fetch(`${restURL}/entries`, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation,resolution=merge-duplicates',
    },
    body: JSON.stringify(entry),
  })
  if (!res.ok) throw new Error(`Upsert 失败: ${res.status} ${await res.text()}`)
}

export async function deleteEntry(id: string): Promise<void> {
  return supabaseDelete(`entries?id=eq.${id}`)
}

export async function updateCollaborators(entryId: string, names: string[]): Promise<void> {
  const res = await fetch(`${restURL}/entries?id=eq.${entryId}`, {
    method: 'PATCH',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal',
    },
    body: JSON.stringify({ contributor_names: names }),
  })
  if (!res.ok) throw new Error(`更新合编者失败: ${res.status}`)
}

export async function uploadEntryImage(file: Blob, fileName?: string): Promise<string> {
  return uploadImage(file, fileName)
}

export async function persistImageFromURL(url: string): Promise<string> {
  const res = await fetch(url)
  const blob = await res.blob()
  return uploadImage(blob)
}

export async function uploadBase64Image(base64: string): Promise<string> {
  const clean = base64.includes(';base64,') ? base64.split(';base64,')[1] : base64
  const bytes = Uint8Array.from(atob(clean), c => c.charCodeAt(0))
  const blob = new Blob([bytes], { type: 'image/jpeg' })
  return uploadImage(blob)
}
