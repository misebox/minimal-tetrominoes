import random
import strutils
import sequtils
import algorithm
import times
import os

import nimbox

const
  w = 12
  h = 21
  RIGHT = true
  LEFT = false
  shapes = @[0xf0, 0xcc, 0x6c, 0xc6, 0x8e, 0x2e, 0x4e]

type
  MinoState {.pure.} = enum
    falling
    landing
    landed
  Pile = object
    lines: seq[string]
  Mino = object
    lines: seq[string]
    x: int
    y: int
    w: int
    h: int
    state: MinoState

proc load_shape(shape: int): seq[string] =
  var lines = @[newString(4), newString(4)]
  for i in 0..7:
    lines[i div 4][i mod 4] = if (shape and (1 shl (7-i))) > 0: '#' else: ' '
  # trim
  let w = lines.mapIt(it.rfind('#')).max + 1
  if w < 8: lines.applyIt(it[0..<w])
  lines.keepItIf('#' in it)
  lines

proc newMino(lines: seq[string], x, y: int): Mino =
  Mino(x: x, y: y, w: lines[0].len, h: lines.len, state: MinoState.falling, lines: lines)

proc calcRotate(m: Mino, isRight: bool): seq[string] =
  let
    w = m.lines.len
    h = m.lines[0].len
  var rotated: seq[string] = @[]
  for y in 0..<h:
    var line = newString(w)
    for x in 0..<w:
      line[x] = if isRight: m.lines[w-x-1][y] else: m.lines[x][h-y-1]
    rotated.add line
  rotated
      
proc collide(m: Mino, p: Pile, dx, dy: int): bool =
  for y in 0..<m.h:
    for x in 0..<m.w:
      let px = m.x + x + dx
      let py = m.y + y + dy
      if p.lines[py][px+1] != ' ' and m.lines[y][x] != ' ':
        return true
  return false

proc rotate(m: var Mino, p: Pile, isRight: bool) =
  let rotated = newMino(m.calcRotate(isRight), m.x, m.y)
  if rotated.collide(p, 0, 0) == false:
    m = rotated

proc newPile(): Pile = 
  var lines: seq[string] = (0..<h).mapIt('|' & (if it < 20: ' ' else: '=').repeat(10) & '|')
  Pile(lines: lines)

proc move(m: var Mino, p: Pile, dx, dy: int): bool =
  if m.collide(p, dx, dy): return false
  m.x += dx
  m.y += dy
  true

proc merged(p: Pile, m: Mino): seq[string] =
  var lines: seq[string] = p.lines
  for y in 0..<m.h:
    for x in 0..<m.w:
      if m.lines[y][x] == '#': 
        lines[m.y+y][m.x+x+1] = '#'
  lines

proc pileUp(p: var Pile, m: var Mino) =
  p.lines = p.merged(m)
  m.state = MinoState.landed

proc clearLine(p: var Pile): int =
  var pt = 0
  for y in 0..<h-1:
    if p.lines[y][1..w-2] == '#'.repeat(w-2):
      p.lines.delete y
      p.lines.insert('|' & ' '.repeat(w-2) & '|')
      pt += (pt + 10)
  pt

proc createMino(): Mino =
  var lines = load_shape(sample(shapes))
  newMino(lines, 5 - lines[0].len div 2, 0)
  
proc main() =
  randomize()
  var pile = newPile()
  var mino = createMino()
  var nb = newNimbox()
  defer: nb.shutdown()
  var ch: char
  var evt: Event
  var t = epochTime()
  var msec: int = 0
  var score = 0

  proc display() =
    nb.clear()
    nb.print(0, 0, "Tetrominoes")
    for y, line in pile.merged(mino):
      nb.print(0, y+2, line)
    nb.print(0, h+2, "score: " & $score)
    nb.print(0, h+3, "lhj:→ ← ↓, Kk:rotate LR, Space: drop")
    nb.present()
    sleep(10)

  while true:
    display()
    evt = nb.peekEvent(1000)
    case evt.kind:
      of EventType.Key:
        if evt.sym == Symbol.Escape:
          break
        if evt.sym == Symbol.Space:
          while mino.move(pile, 0,1): display()
        ch = evt.ch
        case ch:
          of 'd':
            while mino.move(pile, 0,1): display()
          of 'f':
            while mino.move(pile, 0,1): display()
          of 'k': mino.rotate(pile, RIGHT)
          of 'K': mino.rotate(pile, LEFT)
          of 'j': discard mino.move(pile, 0, 1)
          of 'h': discard mino.move(pile, -1, 0)
          of 'l': discard mino.move(pile, 1, 0)
          else: discard
      else: discard
    let now = epochTime()
    msec += ((now - t) * 1000).int
    t = now
    if msec > 1000:
      msec -= 1000
      if not mino.move(pile, 0, 1):
        pile.pileUp(mino)
        score += pile.clearLine()
        mino = createMino()

main()
