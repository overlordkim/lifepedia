import { type ReactNode } from 'react'

export function parseWikiText(
  text: string,
  onBlueLink?: (title: string) => void,
  onRedLink?: (title: string) => void,
): ReactNode[] {
  const pattern = /(\[\[([^\]]+)\]\]|\{\{([^}]+)\}\}|\[来源请求\])/g
  const parts: ReactNode[] = []
  let lastIndex = 0
  let match: RegExpExecArray | null

  while ((match = pattern.exec(text)) !== null) {
    if (match.index > lastIndex) {
      parts.push(text.slice(lastIndex, match.index))
    }

    if (match[2]) {
      const title = match[2]
      parts.push(
        <span
          key={`blue-${match.index}`}
          className="text-wiki-blue underline decoration-1 underline-offset-2 cursor-pointer hover:opacity-70"
          onClick={() => onBlueLink?.(title)}
        >
          {title}
        </span>
      )
    } else if (match[3]) {
      const title = match[3]
      parts.push(
        <span
          key={`red-${match.index}`}
          className="text-wiki-red underline decoration-1 underline-offset-2 cursor-pointer hover:opacity-70"
          onClick={() => onRedLink?.(title)}
        >
          {title}
        </span>
      )
    } else {
      parts.push(
        <sup key={`cite-${match.index}`} className="text-wiki-blue text-[10px] cursor-help">[来源请求]</sup>
      )
    }

    lastIndex = match.index + match[0].length
  }

  if (lastIndex < text.length) {
    parts.push(text.slice(lastIndex))
  }

  return parts
}

export function extractBlueLinks(text: string): string[] {
  const pattern = /\[\[([^\]]+)\]\]/g
  const links: string[] = []
  let m: RegExpExecArray | null
  while ((m = pattern.exec(text)) !== null) links.push(m[1])
  return [...new Set(links)]
}

export function extractRedLinks(text: string): string[] {
  const pattern = /\{\{([^}]+)\}\}/g
  const links: string[] = []
  let m: RegExpExecArray | null
  while ((m = pattern.exec(text)) !== null) links.push(m[1])
  return [...new Set(links)]
}
