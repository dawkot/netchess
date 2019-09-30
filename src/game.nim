import tables, hashes, options

## vectors

type Vec* = object
  x*, y*: int

proc v*(x, y: int): Vec = Vec(x: x, y: y)
proc hash(v: Vec): Hash = hash (v.x, v.y)
proc isPos(v: Vec): bool = v.x in 1..8 and v.y in 1..8

proc `+=`(a: var Vec, b: Vec) =
  a.x += b.x
  a.y += b.y

proc `+`(a, b: Vec): Vec =
  result = a
  result += b

## board

type
  Team* = bool
  PieceKind* = enum Pawn, Rook, Knight, Bishop, King, Queen
  Piece* = ref object
    kind*: PieceKind
    team*: Team
    dests*: seq[Vec]

var
  pieces: Table[Vec, Piece]
  currentTeam*: Team
  winner*: Option[Team]

proc pieceAt*(v: Vec): Piece =
  if v in pieces:
    return pieces[v]

iterator destsBySteps(pos: Vec, team: Team, steps: varargs[Vec]): Vec =
  for s in steps:
    var v = pos + s
    while v.isPos:
      if (let p = pieceAt v; p != nil):
        if p.team != team: yield v
        break
      yield v
      v += s

iterator destsByOffsets(pos: Vec, team: Team, offsets: varargs[Vec]): Vec =
  for o in offsets:
    let v = pos + o
    if not v.isPos: continue
    let p = pieceAt v
    if p == nil or p.team != team: yield v

proc forward(t: Team): Vec =
  if t: v(0, 1) else: v(0, -1)

const
  Left = v(-1, 0)
  Right = v(1, 0)
  RookSteps = @[v(0, 1), v(0, -1), v(1, 0), v(-1, 0)]
  BishopSteps = @[v(1, 1), v(1, -1), v(-1, 1), v(-1, -1)]
  KnightOffsets = @[
    v(2, 1), v(-2, 1), v(2, -1), v(-2, -1),
    v(1, 2), v(-1, 2), v(1, -2), v(-1, -2)]

iterator dests(kind: PieceKind, pos: Vec, team: Team): Vec =
  template collect(x) = (for v in x: yield v)
  case kind
  of Rook: collect destsBySteps(pos, team, RookSteps)
  of Knight: collect destsByOffsets(pos, team, KnightOffsets)
  of Bishop: collect destsBySteps(pos, team, BishopSteps)
  of King: collect destsByOffsets(pos, team, RookSteps & BishopSteps)
  of Queen: collect destsBySteps(pos, team, RookSteps & BishopSteps)
  of Pawn:
    let f = pos + team.forward
    if pieceAt(f) == nil: yield f
    let (l, r) = (f + Left, f + Right)
    if (let p = pieceAt(l); p != nil and p.team != team): yield l
    if (let p = pieceAt(r); p != nil and p.team != team): yield r

proc updateDests =
  for pos, p in pieces:
    p.dests.setLen 0
    for v in dests(p.kind, pos, p.team):
      p.dests.add v

proc resetGame* =
  winner = none Team
  currentTeam = default Team
  pieces.clear
  for x in 1..8:
    for y in [1, 2, 7, 8]:
      let team = y in [1, 2]
      let kind =
        if y in [2, 7]: Pawn
        elif x in [1, 8]: Rook
        elif x in [2, 7]: Knight
        elif x in [3, 6]: Bishop
        elif x == 4: King
        else: Queen
      pieces[v(x, y)] = Piece(team: team, kind: kind)
  updateDests()

proc canMovePiece*(src, dest: Vec): bool =
  let p = pieceAt src
  p != nil and p.team == currentTeam and dest in p.dests

proc movePiece*(src, dest: Vec) =
  assert canMovePiece(src, dest)
  if (let p = pieceAt dest; p != nil and p.kind == King):
    winner = some currentTeam
  pieces[dest] = pieces[src]
  pieces.del src
  currentTeam = not currentTeam
  updateDests()