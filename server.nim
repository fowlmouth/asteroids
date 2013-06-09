
import lib/ast_comps, lib/ast_packets
import math, tables
import enet, enet_pkt_utils
import fowltek/entitty, fowltek/idgen, fowltek/tmaybe,
  fowltek/bbtree, fowltek/boundingbox
randomize()

type
  Client = object
    peer: enet.PPeer


type
  PServ* = var TServer
  TServer* = object
    entities: seq[TEntity]
    activeEntities*: seq[int]
    domain: TDomain
    bbTree: TBBTree[int]
    address: enet.TAddress
    host: enet.PHost
    event: enet.TEvent
    ent_ID_counter: TIdgen[int]
    
    clientType: PTypeInfo

proc readyComponentTypes* (s: PServ) =
  s.clientType = s.domain.getTypeinfo(Named, Client)

proc newServ* (port = 8024): TServer =
  if enet.initialize() != 0:
    quit "Could not initialize enet!"
  
  result.entities = @[]
  result.bbtree = newBBtree[int]()
  result.activeEntities = @[]
  result.ent_id_counter = newidgen[int]()
  
  result.domain = newDomain()
  result.readyComponentTypes()
  
  result.address = enet.TAddress(
    host: enetHostAny,
    port: 8024)
  
  result.host = enet.createHost(
    result.address.addr, 32, 2,  0,  0)
  if result.host.isNIL:
    quit "Could not create the server!"


proc get_ent* (S: PServ; id: int): PEntity{.inline.} = S.entities[id]

proc add_ent* (S: PServ; ent: TEntity): int =
  result = S.ent_id_counter.get
  S.entities.ensureLen result+1
  S.entities[result] = ent
  S.get_ent(result).id = result
  S.activeEntities.add result
  S.bbtree.insert result, S.get_ent(result).getBoundingBox


import algorithm
proc poll* (S: PServ) = 
  # poll enet
  while s.host.hostService(addr s.event, 1) >= 0:
    case s.event.kind
    of EvtConnect:
      echo "New client from $1:$2".format(s.event.peer.address.host, s.event.peer.address.port)
      
      let ID = S.add_ent (S.clientType.newEntity())
      s.event.peer.data = cast[pointer](ID)
      
      #var p: SanityCheck
      var buf = newBuffer(6)
      #buf.writeBE p
      buf.writeCopy SanityCheck()
      
      if s.event.peer.send(0.cuchar, buf.toPacket(FlagReliable)) < 0:
        echo "FAILED"
      else:
        echo "Replied"
      
      discard """ var
        msg = "hello" 
        resp = createPacket(cstring(msg), msg.len + 1, FlagReliable)
      """
    of EvtReceive:
      
      let E_ID = cast[int](s.event.peer.data)
      
      
      echo "Recvd ($1) from #$3 $2 ".format(
        s.event.packet.dataLength,
        s.event.packet.data,
        E_ID)
      
      
      destroy(s.event.packet)
      
    of EvtDisconnect:
      echo "Disconnected"
      s.event.peer.data = nil
    else:
      discard
  
  if random(10) == 0:
    S.activeEntities.sort cmp[int]

proc add_ents* (S: PServ; num: int, components: varargs[int, `componentID`]): seq[int] =
  var ty = S.domain.getTypeinfo(components)

  newSeq result, 0
  for i in 1 .. num:
    let id = S.add_ent(ty.newEntity)
    result.add id

proc each_ent_cb* (ids: seq[int]; S: PServ; cb: proc(X: PEntity)) =
  for id in ids:
    cb S.get_ent(id)

template eachEntity* (serv; body: stmt): stmt {.immediate,dirty.}=
  #for idx in 0 .. high(serv.entities):
  for id in serv.activeEntities:  
    template entity: expr  = serv.entities[id]
    #if entity.id > -1:
    body

proc update* (S: PServ; dt: float) {.inline.}=
  eachEntity(S): 
    entity.update dt
    S.bbtree.update entity.id, entity.getBoundingBox


type
  AstRec = object
    file: string
    radius: float

var Asteroids = [
  AstRec(file: "Rock24b_24x24.png"),  
  AstRec(file: "Rock48b_48x48.png"),
  AstRec(file: "Rock64b_64x64.png"),
  AstRec(file: "Meteor_32x32.png" ),
  AstRec(file: "Rock32a_32x32.png"),
  AstRec(file: "Rock48c_48x48.png"),
  AstRec(file: "Rock64c_64x64.png"),
  AstRec(file: "Rock24a_24x24.png"),
  AstRec(file: "Rock48a_48x48.png"),
  AstRec(file: "Rock64a_64x64.png")]
proc init_random_asteroid (X: PEntity)= 
  let ast = Asteroids[random(asteroids.len)].addr
  #X.loadSimpleAnim NG, ast.file
  #X[BoundingCircle] = BoundingCircle(radius: X[SpriteInst].sprite.center.x.float)

proc add_asteroids (S: PServ, num = 10) =
  S.
    add_ents(
      num,
      Pos, Vel, SpriteInst, SimpleAnim, ToroidalBounds, 
      Health, BoundingCircle).
    each_ent_cb(S, init_random_asteroid)



when isMainModule:
  import parseopt
  var port = 8024
  var cfg: string
  
  for ki, k,v in getOpt():
    case ki
    of CmdLongOption, CmdShortOption:
      case k.toLower
      of "p","port":
        port = parseInt(v)
      of "cfg":
        cfg = v
      else: 
        nil
    else: nil
  
  echo "Reading cfg ", cfg, "."
  
  echo "Starting server on port ", port, "."
  var server = newServ(port = port)

  echo "Running."
  var running = true
  while running:
    server.poll()
  
  