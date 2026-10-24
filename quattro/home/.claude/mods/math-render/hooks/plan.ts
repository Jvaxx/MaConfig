// Turns an assistant reply's markdown into blocks the mod can draw: plain
// markdown, display formulas, and paragraphs that carry inline formulas
// (drawn as wrapped rows of words and one-row images).
import { GENERATED_MATH_LANGUAGE, expandMathInMarkdown } from './scan.ts'

export type Formula = {
  latex: string
  display: boolean
  inline: boolean
  /** The span as written, delimiters included: the fallback text. */
  source: string
  /**
   * Where an inline formula sits in its whole-cell image: toward the text it
   * touches, so `$x$,` shows no gap before the comma.
   */
  align?: 'start' | 'center' | 'end'
}

export type Run =
  | { kind: 'text'; text: string; bold?: boolean; italic?: boolean; strike?: boolean; code?: boolean; href?: string }
  | { kind: 'formula'; id: number }

export type FlowLine = {
  /** `heading` lines are bold, `quote` lines carry a bar. */
  style: 'plain' | 'heading' | 'quote'
  /** A list marker as drawn (`-`, `1.`), empty for none. */
  marker: string
  /** Leading columns before the marker (nested lists). */
  indent: number
  runs: Run[]
}

export type Block =
  | { kind: 'markdown'; text: string }
  | { kind: 'display'; id: number }
  | { kind: 'flow'; lines: FlowLine[] }

export type Plan = { formulas: Formula[]; blocks: Block[] }

const INLINE_OPEN = ''
const INLINE_CLOSE = ''
const DISPLAY_MARK = ''
const TOKEN = /(\d+)/g
const DISPLAY_FENCE = new RegExp(`^(\`{4,})${GENERATED_MATH_LANGUAGE}\\s*$`)
const CODE_FENCE = /^\s{0,3}(`{3,}|~{3,})/

/** The reply as blocks, or undefined when it holds no complete formula. */
export function planMessage(text: string): Plan | undefined {
  const formulas: Formula[] = []
  const transformed = expandMathInMarkdown(text, (latex, display, context) => {
    const inline = !display && !context.standalone
    const id = formulas.push({ latex, display, inline, source: text.slice(context.start, context.end) }) - 1
    return inline
      ? { text: `${INLINE_OPEN}${id}${INLINE_CLOSE}`, rawInline: true }
      : { text: `${DISPLAY_MARK}${id}${INLINE_CLOSE}`, forceBlock: true }
  })
  if (formulas.length === 0) return undefined

  const blocks: Block[] = []
  let pending: string[] = []
  const flush = () => {
    const joined = pending.join('\n').replace(/^\n+|\n+$/g, '')
    if (joined.trim()) blocks.push({ kind: 'markdown', text: joined })
    pending = []
  }
  const sourceOf = (line: string) => line.replace(TOKEN, (_, id) => formulas[Number(id)]!.source)

  const lines = transformed.split('\n')
  let index = 0
  while (index < lines.length) {
    const line = lines[index]!

    const display = DISPLAY_FENCE.exec(line)
    if (display) {
      flush()
      const fence = display[1]!
      const body: string[] = []
      index++
      while (index < lines.length && lines[index]!.trim() !== fence) body.push(lines[index++]!)
      index++
      const id = /(\d+)/.exec(body.join('\n'))
      if (id) blocks.push({ kind: 'display', id: Number(id[1]) })
      continue
    }

    const code = CODE_FENCE.exec(line)
    if (code) {
      // A code fence: copied whole, the scanner left formulas inside it alone.
      const marker = code[1]!
      pending.push(line)
      index++
      while (index < lines.length) {
        const inner = lines[index++]!
        pending.push(inner)
        if (inner.trim().startsWith(marker[0]!.repeat(marker.length)) && inner.trim().replace(/[`~]/g, '') === '') break
      }
      continue
    }

    if (line.trim() === '') {
      pending.push(line)
      index++
      continue
    }

    // A paragraph: up to the next blank line, fence or display formula.
    const paragraph: string[] = []
    while (
      index < lines.length &&
      lines[index]!.trim() !== '' &&
      !DISPLAY_FENCE.test(lines[index]!) &&
      !CODE_FENCE.test(lines[index]!)
    ) {
      paragraph.push(lines[index++]!)
    }

    if (!paragraph.some(one => one.includes(INLINE_OPEN))) {
      pending.push(...paragraph)
    } else if (paragraph.every(one => one.trim().startsWith('|'))) {
      // Tables keep the markdown renderer; their formulas stay as written.
      pending.push(...paragraph.map(sourceOf))
    } else {
      flush()
      const flow = flowLines(paragraph)
      for (const line of flow) alignFormulas(line.runs, formulas)
      blocks.push({ kind: 'flow', lines: flow })
    }
  }
  flush()

  return { formulas, blocks }
}

function alignFormulas(runs: Run[], formulas: Formula[]) {
  for (const { pieces } of words(runs)) {
    pieces.forEach((piece, at) => {
      if (piece.kind !== 'formula') return
      const touchesAfter = at < pieces.length - 1
      const touchesBefore = at > 0
      formulas[piece.id]!.align =
        touchesAfter && !touchesBefore ? 'end' : touchesBefore && !touchesAfter ? 'start' : 'center'
    })
  }
}

function flowLines(paragraph: string[]): FlowLine[] {
  const result: { style: FlowLine['style']; marker: string; indent: number; text: string }[] = []
  for (const raw of paragraph) {
    const heading = /^\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$/.exec(raw)
    const quote = /^\s{0,3}>\s?(.*)$/.exec(raw)
    const item = /^(\s*)([-*+]|\d{1,9}[.)])\s+(.*)$/.exec(raw)
    if (heading) result.push({ style: 'heading', marker: '', indent: 0, text: heading[1]! })
    else if (item) result.push({ style: 'plain', marker: item[2]!, indent: item[1]!.length, text: item[3]! })
    else if (quote && (result.length === 0 || result.at(-1)!.style !== 'quote'))
      result.push({ style: 'quote', marker: '', indent: 0, text: quote[1]! })
    else if (result.length === 0) result.push({ style: 'plain', marker: '', indent: 0, text: raw.trim() })
    else {
      // A continuation line joins the line it continues.
      const last = result.at(-1)!
      const continued = quote && last.style === 'quote' ? quote[1]! : raw.trim()
      last.text = `${last.text.replace(/\s+$/, '')} ${continued.trim()}`
    }
  }
  return result.map(({ style, marker, indent, text }) => ({ style, marker, indent, runs: inlineRuns(text) }))
}

type Style = { bold?: boolean; italic?: boolean; strike?: boolean }

/** Inline markdown (emphasis, code, links, escapes) and formula tokens as runs. */
export function inlineRuns(text: string, base: Style = {}, href?: string): Run[] {
  const runs: Run[] = []
  let style: Style = { ...base }
  let buffer = ''
  const push = () => {
    if (buffer) runs.push({ kind: 'text', text: buffer, ...style, ...(href ? { href } : {}) })
    buffer = ''
  }
  const toggle = (key: keyof Style) => {
    push()
    style = { ...style, [key]: !style[key] }
  }

  let index = 0
  while (index < text.length) {
    const char = text[index]!

    if (char === INLINE_OPEN) {
      const close = text.indexOf(INLINE_CLOSE, index)
      push()
      runs.push({ kind: 'formula', id: Number(text.slice(index + 1, close)) })
      index = close + 1
      continue
    }

    if (char === '\\' && /[!-/:-@[-`{-~]/.test(text[index + 1] ?? '')) {
      buffer += text[index + 1]
      index += 2
      continue
    }

    if (char === '`') {
      const run = /^`+/.exec(text.slice(index))![0]
      const close = text.indexOf(run, index + run.length)
      if (close > 0) {
        push()
        const body = text.slice(index + run.length, close)
        runs.push({ kind: 'text', text: body.length > 2 && body.startsWith(' ') && body.endsWith(' ') ? body.slice(1, -1) : body, code: true })
        index = close + run.length
        continue
      }
    }

    if (char === '[') {
      const link = /^\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)/.exec(text.slice(index))
      if (link) {
        push()
        runs.push(...inlineRuns(link[1]!, style, link[2]!))
        index += link[0].length
        continue
      }
    }

    const pair = text.slice(index, index + 2)
    if (pair === '**' || pair === '__' || pair === '~~') {
      const key = pair === '~~' ? 'strike' : 'bold'
      if (style[key] || text.indexOf(pair, index + 2) > index + 2) {
        toggle(key)
        index += 2
        continue
      }
    }

    if (char === '*' || char === '_') {
      const before = text[index - 1] ?? ' '
      const after = text[index + 1] ?? ' '
      const opens = !style.italic && !/\s/.test(after) && (char === '*' || !/\w/.test(before))
      const closes = style.italic && !/\s/.test(before) && (char === '*' || !/\w/.test(after))
      if ((opens && text.indexOf(char, index + 1) > index + 1) || closes) {
        toggle('italic')
        index++
        continue
      }
    }

    buffer += char
    index++
  }
  push()
  return runs
}

export type Piece = Run
/** A run of pieces with no whitespace between them: never split across lines. */
export type Word = { pieces: Piece[]; spaceAfter: boolean }

/** The runs as words, so a formula keeps the punctuation it touches. */
export function words(runs: Run[]): Word[] {
  const result: Word[] = []
  let current: Piece[] = []
  const end = (spaceAfter: boolean) => {
    if (current.length > 0) result.push({ pieces: current, spaceAfter })
    else if (spaceAfter && result.length > 0) result.at(-1)!.spaceAfter = true
    current = []
  }
  for (const run of runs) {
    if (run.kind === 'formula' || run.code) {
      current.push(run)
      continue
    }
    const parts = run.text.split(/(\s+)/)
    for (const part of parts) {
      if (part === '') continue
      if (/^\s+$/.test(part)) end(true)
      else current.push({ ...run, text: part })
    }
  }
  end(false)
  return result
}
