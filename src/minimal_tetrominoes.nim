import random, strutils, sequtils, algorithm, times, os
import nimbox

const
  (w, h) = (12, 21)
  (LEFT, RIGHT) = (false, true)
  shapes = @[0xf0, 0xcc, 0x6c, 0xc6, 0x8e, 0x2e, 0x4e]

type
  MinoState {.pure.} = enum falling landing landed
  GameState {.pure.} = enum playing pause over
  Pile = object
    lines: seq[string]
  Mino = object
    lines: seq[string]
    x, y, w, h: int
    state: MinoState

proc load_shape(shape: int): seq[string] =
  var lines = @[newString(4), newString(4)]
  for i in 0..7:
    lines[i div 4][i mod 4] = if (shape and (1 shl (7-i))) > 0: '#' else: ' '
  # trim
  let edge = lines.mapIt(it.rfind('#')).max + 1
  if edge < 8: lines.applyIt(it[0..<edge])
  lines.filterIt('#' in it)

proc newMino(lines: seq[string], x, y: int): Mino =
  Mino(x: x, y: y, w: lines[0].len, h: lines.len, state: MinoState.falling, lines: lines)

proc calcRotate(m: Mino, isRight: bool): seq[string] =
  let
    rw = m.lines.len
    rh = m.lines[0].len
  var rotated: seq[string] = @[]
  for y in 0..<rh:
    var line = newString(rw)
    for x in 0..<rw:
      line[x] = if isRight: m.lines[rw-x-1][y] else: m.lines[x][rh-y-1]
    rotated.add line
  rotated

proc collide(m: Mino, p: Pile, dx, dy: int): bool =
  for y in 0..<m.h:
    for x in 0..<m.w:
      let px = m.x + x + dx
      let py = m.y + y + dy
      if p.lines[py][px+1] != ' ' and m.lines[y][x] != ' ': return true
  false

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
      if m.lines[y][x] != ' ':
        lines[m.y+y][m.x+x+1] = '#'
  lines

proc pileUp(p: var Pile, m: var Mino) =
  p.lines = p.merged(m)
  m.state = MinoState.landed

proc clearLine(p: var Pile): int =
  var pt = 0
  for y in 0..<h-1:
    if p.lines[y][1..w-2] == '#'.repeat(w-2):
      pt += (pt + 10)
      p.lines.delete y
      p.lines.insert('|' & ' '.repeat(w-2) & '|')
  pt

proc createMino(): Mino =
  var lines = load_shape(sample(shapes))
  newMino(lines, 5 - lines[0].len div 2, 0)

proc main() =
  randomize()
  var nb = newNimbox()
  defer: nb.shutdown()
  var evt: Event
  var t = epochTime()
  var msec: int = 0

  var pile: Pile
  var mino: Mino
  var score: int
  var state: GameState

  proc display() =
    nb.clear()
    let tbw = tbWidth()
    let sx = (tbw - w) div 2
    nb.print(sx, 0, "Tetrominoes")
    if state == GameState.pause:
      nb.print(sx, 1, "-- PAUSE --")
      nb.print(sx, 2, "[Hit P key]")
    elif state == GameState.over:
      nb.print(sx, 1, "-GAME OVER-")
      nb.print(sx, 2, "[Hit ENTER]")
    for y, line in pile.merged(mino):
      nb.print(sx, y+3, line)
    nb.print(sx, h+3, "SCORE: " & $score)
    nb.print(sx, h+5, "ESC: QUIT")
    nb.print(sx, h+6, "← , ↓ , → : H, J, L")
    nb.print(sx, h+7, "DROP: SPACE")
    nb.print(sx, h+8, "ROTATE L, R: SHIFT+K, K")
    nb.print(sx, h+9, "PAUSE: P")
    nb.print(sx, h+10, "BACK TO GAME: ENTER")
    nb.present()
    sleep(10)

  proc drop(m: var Mino, p: Pile) =
    while m.move(p, 0, 1): display()

  proc pause() =
    if state == GameState.playing: state = GameState.pause
    elif state == GameState.pause: state = GameState.playing

  proc gameover() =
    state = GameState.over

  proc initialize() =
    state = GameState.playing
    mino = createMino()
    pile = newPile()
    score = 0

  initialize()

  while true:
    evt = nb.peekEvent(1000)
    case evt.kind:
      of EventType.Key:
        if evt.sym == Symbol.Escape: break
        elif evt.sym == Symbol.Enter and state == GameState.over:
          initialize()
        elif evt.sym == Symbol.Space and state == GameState.playing:
          mino.drop(pile)
        case evt.ch:
          of 'd': mino.drop(pile)
          of 'f': mino.drop(pile)
          of 'k': mino.rotate(pile, RIGHT)
          of 'K': mino.rotate(pile, LEFT)
          of 'j': discard mino.move(pile, 0, 1)
          of 'h': discard mino.move(pile, -1, 0)
          of 'l': discard mino.move(pile, 1, 0)
          of 'p': pause()
          else: discard
      else: discard

    if state == GameState.playing:
      let now = epochTime()
      msec += ((now - t) * 1000).int
      t = now
      if msec > 1000:
        msec -= 1000
        if not mino.move(pile, 0, 1):
          pile.pileUp(mino)
          score += pile.clearLine()
          mino = createMino()
          if mino.collide(pile, 0, 0):
            gameover()
    display()

main()
