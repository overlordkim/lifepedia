import { callEdgeFunction } from '../lib/supabase'

export async function generateImage(prompt: string): Promise<string> {
  const result = await callEdgeFunction<{ url: string }>('generate-image', {
    prompt,
    size: '1024x1024',
  })
  return result.url
}
