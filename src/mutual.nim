import game

type
  ClientMsg* = object
    src*, dest*: Vec

  ServerMsgKind* = enum
    InitGame, OpponentMoved, ServerFull, OpponentDisconnected

  ServerMsg* = object
    case kind*: ServerMsgKind
    of InitGame: yourTeam*, firstTeam*: Team
    of OpponentMoved: src*, dest*: Vec
    else: discard

const
  ServerPort* = 9001
  ServerAddr* = "localhost"

template findIt*(coll, cond): untyped =
  var res: typeof(coll.items, typeOfIter)
  for it {.inject.} in coll:
    if not cond: continue
    res = it
    break
  res