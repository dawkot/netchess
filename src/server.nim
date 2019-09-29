import asynchttpserver, asyncdispatch, ws, json, game, mutual
import sequtils, options

var connections: array[Team, Websocket]

proc startGameLoop {.async.} =
  resetGame()
  try:
    for team, conn in connections:
      await conn.send($ %*ServerMsg(kind: InitGame, firstTeam: currentTeam, yourTeam: team))
    while winner.isNone and connections.allIt(it.readyState in {Open, Closing}):
      let (a, b) = (connections[currentTeam], connections[not currentTeam])
      let m = (await a.receiveStrPacket).parseJson.to ClientMsg
      if not canMovePiece(m.src, m.dest): continue
      if b.readyState != Open:
        await a.send($ %*ServerMsg(kind: OpponentDisconnected))
        break
      await b.send($ %*ServerMsg(kind: OpponentMoved, src: m.src, dest: m.dest))
      movePiece m.src, m.dest
  except WebSocketError:
    let x = connections.findIt(it.readyState == Open)
    await x.send($ %*ServerMsg(kind: OpponentDisconnected))
  finally:
    for it in connections.mitems:
      if it == nil: continue
      it.close
      it = nil

proc serve(req: Request) {.async.} = {.gcsafe.}:
  if req.url.path != "/ws": return
  let conn = await req.newWebSocket
  let i = connections.find nil
  if i < 0:
    await conn.send($ %*ServerMsg(kind: ServerFull))
    conn.close
  else:
    connections[Team i] = conn

## init

proc main {.async.} =
  while true:
    await sleepAsync 150
    if not connections.allIt(it != nil and it.readyState == Open): continue
    await startGameLoop()

asyncCheck main()
waitFor newAsyncHttpServer().serve(Port ServerPort, serve)