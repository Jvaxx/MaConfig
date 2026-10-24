import { expect, test } from 'claude-code/testing'

import { inlineRuns, planMessage, words } from './plan.ts'

test('leaves replies without formulas to the engine', async () => {
  expect(planMessage('It costs $5 and $10 today.')).toBe(undefined)
  expect(planMessage('Use `$x$` in code.')).toBe(undefined)
  expect(planMessage('```\n$$x$$\n```')).toBe(undefined)
})

test('splits display formulas out of the markdown', async () => {
  const plan = planMessage('Before.\n\n$$\\int_0^1 x\\,dx$$\n\nAfter **bold**.')!
  expect(plan.formulas.length).toBe(1)
  expect(plan.formulas[0]!.display).toBe(true)
  expect(plan.blocks.map(block => block.kind)).toEqual(['markdown', 'display', 'markdown'])
  expect(plan.blocks[2]).toEqual({ kind: 'markdown', text: 'After **bold**.' })
})

test('a lone inline formula on its line is drawn as a display', async () => {
  const plan = planMessage('Text\n\n$e^{i\\pi}+1=0$\n')!
  expect(plan.formulas[0]!.inline).toBe(false)
  expect(plan.blocks.map(block => block.kind)).toEqual(['markdown', 'display'])
})

test('paragraphs with inline formulas become flow lines', async () => {
  const plan = planMessage('# Title\n\nLet $x^2$ be **big**,\nand go on.\n\n- item $a$\n  1. sub $b$')!
  expect(plan.blocks.map(block => block.kind)).toEqual(['markdown', 'flow', 'flow'])
  const paragraph = plan.blocks[1]!
  if (paragraph.kind !== 'flow') throw new Error('not flow')
  expect(paragraph.lines.length).toBe(1)
  expect(paragraph.lines[0]!.runs).toEqual([
    { kind: 'text', text: 'Let ' },
    { kind: 'formula', id: 0 },
    { kind: 'text', text: ' be ' },
    { kind: 'text', text: 'big', bold: true },
    { kind: 'text', text: ', and go on.', bold: false },
  ])
  const list = plan.blocks[2]!
  if (list.kind !== 'flow') throw new Error('not flow')
  expect(list.lines.map(line => [line.marker, line.indent])).toEqual([['-', 0], ['1.', 2]])
})

test('tables keep the markdown renderer with formulas as written', async () => {
  const plan = planMessage('| a | b |\n|---|---|\n| $x$ | 1 |\n\n$$y$$')!
  expect(plan.blocks[0]).toEqual({ kind: 'markdown', text: '| a | b |\n|---|---|\n| $x$ | 1 |' })
})

test('words keep formulas attached to their punctuation', async () => {
  const runs = inlineRuns('see 0, then `a b` [link](https://x.y)')
  const grouped = words(runs).map(word => word.pieces.map(piece => (piece.kind === 'formula' ? '<f>' : piece.text)).join(''))
  expect(grouped).toEqual(['see', '<f>,', 'then', 'a b', 'link'])
})

test('inline formulas lean toward the punctuation they touch', async () => {
  const plan = planMessage('So $a$, then ($b$) and x$c$ or $d$ end.')!
  expect(plan.formulas.map(f => f.align)).toEqual(['end', 'center', 'start', 'center'])
})
