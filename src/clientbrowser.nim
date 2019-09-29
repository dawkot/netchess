import dom, json, jswebsockets, mutual, logging, options, strformat
import karax / [karax, karaxdsl, vdom, vstyles]
import game except movePiece

type
  Connection = enum CNone, CConnected, CConnecting, CFailed
  PrevGameResult = enum
    RNone, RWon, RLost, RServerFull
    ROpponentDisconnected, RLostConnection

const InvalidPos = v(int.low, int.high)

var
  conn: WebSocket
  prevGameResult = RNone
  connection = CNone

## match state

var
  selected, hovered: Vec
  yourTeam: Team
  gameStarted = false

proc movePiece(src, dest: Vec) =
  game.movePiece src, dest
  if connection == CConnected and winner.isSome:
    prevGameResult = if winner.get == yourTeam: RWon else: RLost

proc canSelect(v: Vec): bool =
  let p = pieceAt v
  p != nil and p.team == currentTeam and p.dests.len > 0 and
  connection != CConnected or currentTeam == yourTeam

proc isCurrentTeam: bool =
  connection != CConnected or currentTeam == yourTeam

proc onClickCell(v: Vec) =
  if canMovePiece(selected, v) and isCurrentTeam():
    if connection == CConnected:
      echo "SENDING!!!!!!!"
      conn.send($ %*ClientMsg(src: selected, dest: v))
    movePiece selected, v
    selected = InvalidPos
  else:
    let p = pieceAt v
    if p == nil or p.team != currentTeam or p == pieceAt selected:
      selected = InvalidPos
    elif canSelect v:
      selected = v

## new game

proc initConnection =
  prevGameResult = RNone
  connection = CConnecting
  conn = newWebSocket &"ws://{ServerAddr}:{ServerPort}/ws"
  conn.onError = proc(ev: Event) =
    connection = CFailed
    redraw()
  conn.onOpen = proc(ev: Event) =
    connection = CConnected
    redraw()
  conn.onClose = proc(ev: CloseEvent) =
    if connection != CFailed: connection = CNone
    if prevGameResult == RNone: prevGameResult = RLostConnection
    gameStarted = false
    redraw()
  conn.onMessage = proc(ev: MessageEvent) =
    debugEcho "received packet: ", ev.data
    let m = ($ev.data).parseJson.to ServerMsg
    case m.kind
    of OpponentMoved: movePiece m.src, m.dest
    of ServerFull: prevGameResult = RServerFull
    of OpponentDisconnected: prevGameResult = ROpponentDisconnected
    of InitGame:
      resetGame()
      gameStarted = true
      yourTeam = m.yourTeam
      currentTeam = m.firstTeam
    redraw()

proc initLocal =
  prevGameResult = RNone
  gameStarted = true
  if conn != nil: conn.close
  conn = nil
  connection = CNone
  resetGame()

## rendering

proc icon(kind: PieceKind): cstring =
  case kind
  of Pawn: "fas fa-chess-pawn"
  of Rook: "fas fa-chess-rook"
  of Knight: "fas fa-chess-knight"
  of Bishop: "fas fa-chess-bishop"
  of King: "fas fa-chess-king"
  of Queen: "fas fa-chess-queen"

proc color(team: Team): cstring =
  if team: "#ff3860" else: "#3273dc"

proc renderCell(v: Vec): VNode =
  let (p, s, h) = (pieceAt v, pieceAt selected, pieceAt hovered)
  var icon, fg: cstring = ""
  if p != nil:
    icon = icon p.kind
    fg = color p.team
  var butClass: cstring = "button is-large"
  butClass.add:
    if v == selected: " is-primary"
    # importante
    elif p != nil and p.team == currentTeam and p.dests.len > 0 and isCurrentTeam(): " is-warning"
    elif s != nil and v in s.dests: " is-success"
    elif s == nil and h != nil and v in h.dests: " is-success"
    elif v.x mod 2 != v.y mod 2: " is-dark"
    else: " is-white"
  buildHtml button(class=butClass, style={StyleAttr.color: fg}):
    span(class="icon is-small"): italic(class=icon)
    proc onMouseOver = hovered = v
    proc onMouseOut = hovered = InvalidPos
    proc onClick = onClickCell v

proc renderGame: VNode =
  buildHtml tdiv(id="game", class="container has-text-centered"):
    ## whose turn
    h1(class="title", style={StyleAttr.color: currentTeam.color}):
      if connection != CConnected or currentTeam == yourTeam:
        text "Your turn"
      else:
        text "Opponent's turn"
    ## board
    for y in 1..8:
      tdiv(class="buttons"):
        for x in 1..8:
          renderCell v(x, y)

proc renderMenu: VNode =
  buildHtml tdiv(id="menu", class="container has-text-centered"):
    h1(class="title is-1"): text "NetChess"
    case prevGameResult
    of RWon:
      h3(class="subtitle"): text "You won!"
    of RLost:
      h3(class="subtitle"): text "You lost!"
    of RServerFull:
      h3(class="subtitle"): text "server is full"
    of ROpponentDisconnected:
      h3(class="subtitle"): text "opponent disconnected"
    of RLostConnection:
      h3(class="subtitle"): text "lost connection"
    of RNone:
      discard
    tdiv(class="buttons are-large"):
      case connection
      of CFailed:
        button(class="button is-danger"): text "Connect"
      of CConnecting, CConnected:
        button(class="button is-primary is-loading"): text "Connect"
      else:
        button(class="button is-primary", onClick=initConnection): text "Connect"
      button(class="button is-primary", onClick=initLocal): text "Local"

proc renderMain: VNode =
  buildHtml tdiv(class="container", style={textTransform: "capitalize", overflow: "visible"}):
    tdiv(class="hero is-light is-fullheight"):
      tdiv(class="hero-body container"):
        if gameStarted: renderGame()
        else: renderMenu()

## dom

proc elem(tag: string, args: varargs[string]): Element =
  assert args.len mod 2 == 0
  result = document.createElement tag
  for i in countup(1, args.high, 2):
    result.setAttr args[i-1], args[i]

## init

addHandler newConsoleLogger()
document.head.appendChild elem("link", "rel", "stylesheet", "href", "https://cdnjs.cloudflare.com/ajax/libs/bulma/0.7.5/css/bulma.css")
document.head.appendChild elem("link", "rel", "stylesheet", "href", "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.11.2/css/all.css")
resetGame()
setRenderer renderMain