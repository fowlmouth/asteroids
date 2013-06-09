import osproc, os, math, tables, strutils
import enet, lib/ast_comps, lib/ast_packets
import fowltek/entitty, fowltek/sdl2/engine,
  fowltek/idgen, fowltek/vector_math, fowltek/tmaybe, fowltek/bbtree
import_all_sdl2_modules
import_all_sdl2_helpers

randomize()

setImageRoot getAppDir()/"gfx"

var NG =  newSdlEngine()

#var activeServer: TCServ

var arena_bbTree: TBBTree[int]

type
  TClient = object
    event: enet.TEvent
    address: enet.TAddress
    peer: PPeer
    host: PHost
    connected: bool

    id: int 


var 
  entities = newSeq[TEntity](2048)
  activeEntities = newSeq[int](0)
  
  localPlayerID = -1
  
  mouseEntID = -1
var 
  serverProcess = Nothing[PProcess]()
  myClient: TClient

template ENT (id): expr = entities[id] #activeServer.getEnt(id)
template localPlayer:expr = entities[localPlayerID] #activeServer.get_ent(localPlayerID)

template EachEntity(body: stmt): stmt {.immediate.} = 
  for i in activeEntities:
    template entity : expr = ENT(i)
    body

include lib/ast_boilerplate




type
  TEitherDir {.pure.} = enum Left, Right
  TEither[TLeft,TRight] = object
    case dir: TEitherDir
    of TEitherDir.Left: item_l: TLeft
    else:               item_r: TRight

proc Left* (val; right: typedesc): TEither[type(val), right] = TEither(
  dir: TEitherDir.Left,
  item_l: val)
  
proc Right* (val; left: typedesc): TEither[left, type(val)] = TEither(
  dir: TEitherDir.Right,
  item_r: val)

proc isLeft* [A,B] (some: TEitherDir[A,B]): bool {.inline.} = some.dir == TEitherDir.Left
proc isRight*[A,B] (some: TEitherDir[A,B]): bool {.inline.} = some.dir == TEitherDir.Right


proc connect* (address: string; port: int): TMaybe[TClient]=
  var  
    address: enet.TAddress
    peer: PPeer
    client: PHost

  if setHost(address.addr, "localhost") != 0:
    quit "Could not set host"
  address.port = 8024
  
  client = createHost(nil, 1, 2, 0, 0)
  if client.isNIL:
    quit "Could not create client!"


  peer = client.connect(addr address, 2, 0)
  if peer.isNIL:
    quit "No available peers"

  var event: enet.TEvent
  if client.hostService(event, 500) > 0 and event.kind == EvtConnect:
    echo "Connected"
    
  else:
    quit "Connection failed"
  
  result = Just(TClient(
    peer: peer, host: client, address: address, connected: true
  ) )
  arena_bbtree = newBBtree[int]()


proc newLocalServ* (port: int, cfg: string) : TClient =
  serverProcess = startProcess(command = getAppDir() / "server", args = [
    "-cfg:$#" % cfg,
    "-port:$#"% $port
  ] ).Just
  
  let c = connect("localhost", port)
  if not c:
    quit "Fail"
  return c.val
  

proc initialize_local_game (
    ast_count = (if paramCount() == 1: paramStr(1).parseInt.int else: 10)
  ) =
  
  myClient = newLocalServ(8024, "alphazone.json")
  
  
  #activeServer.add_asteroids ast_count
  
  
  discard """ localPlayerID = activeServer.add_ent(activeServer.domain.newEntity(Pos, Vel, SpriteInst, ToroidalBounds, 
    HID_Controller, InputState, Acceleration, Orientation, RollSprite,
    BoundingCircle
  ))

  if(var errorMsg = HID_Dispatcher.requestDevice("Keyboard", LocalPlayer); errorMsg):
    echo "Could not register keyboard: ", errorMsg.val
  LocalPlayer[SpriteInst].loadSprite NG, "hornet_54x54.png"
  LocalPlayer[BoundingCircle].radius = 19.0

  mouseEntID = activeServer.add_ent(activeServer.domain.newEntity(Pos, HID_Controller,
    DebugShape)) 
  mouseEntID.ent[DebugShape] = DebugCircle(5.0)
  if(var err = HID_Dispatcher.requestDevice("Mouse", mouseEntID.ent); err):
    echo "Could not register mouse: ", err.val """


proc `$`* (some: pointer): string = repr(some)

proc `$`* [T] (some: openarray[T]): string = 
  result = "["
  for i in 0 .. <some.len:
    result.add($ some[i])
    if i < some.high:
      result.add ", "
  result.add "]"

import enet_pkt_utils

proc dispatchPacket* (c: var TClient; pkt: PPacket) {.inline.} =
  if pkt.referenceCount >= pkt.dataLength: return
  let pkt_type = pkt.readChar()
  case pkt_type
  of 'a':
    c.peer.sendHiThere("phil")
  
  else: NIL
  
proc poll * (c: var TCLient) =
  var event: enet.TEvent
  while c.host.hostService(event, 1) >= 0 :
    case event.kind
    of EvtReceive:
      c.dispatchPacket event.packet
      
      discard """ echo "Recvd ($1) $2 ".format(
        event.packet.dataLength,
        event.packet.data) """
    
    of EvtDisconnect:
      echo "Disconnected"
      event.peer.data = nil
      c.connected = false
      break
      
    of EvtNone: break
    else:
      echo repr(c.event)


initialize_local_game()


var running = true
var paused = false
var debugDrawEnabled = false
template stopRunning = running = false

var collisions: seq[int] = @[]

while running:
  while NG.pollHandle:
    case NG.evt.kind
    of QuitEvent: stopRunning
    of KeyDown:
      if paused or not HID_Dispatcher.handleEvent("Keyboard", NG.evt):
        let k = NG.evt.evKeyboard.keysym.sym
        case k
        of K_ESCAPE: stopRunning
        of K_P: paused = not paused
        of K_D: debugDrawEnabled = not debugDrawEnabled
        else:nil
    of keyUp:
      if not paused:
        discard HID_Dispatcher.handleEvent("Keyboard", NG.evt)
    of MouseMotion, MouseButtonDown, MouseButtonUp, MouseWheel:
      if not paused: 
        discard HID_Dispatcher.handleEvent("Mouse", NG.evt)
    else:nil

  let dt = NG.frameDeltaFLT
  
  myclient.poll

  eachEntity:
    entity.update dt

  if localPlayerID != -1:
    collisions.setLen 0
    arena_bbtree.collectCollisions localPlayerID, collisions

  NG.setDrawColor 0,0,0,255
  NG.clear

  eachEntity:
    entity.draw NG

  #LocalPlayer.drawDebugStrings NG

  if debugDrawEnabled:
    eachEntity:
      entity.debugDraw NG
    arena_bbtree.debugDraw NG

  for ID in collisions:
    let p = vec2s(ID.ent[pos])
    NG.circleRGBA p.x,p.y, 20, 0,0,255,255      
  
  NG.present

destroy NG
if serverProcess :
  terminate serverProcess.val
  echo "Server shutdown."

