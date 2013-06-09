import fowltek/entitty, fowltek/idgen, enet,
  fowltek/tmaybe, fowltek/bbtree, lib/ast_comps,
  math, tables, fowltek/boundingbox

type
  PServ* = var TServer
  TServer* = object
    entities: seq[TEntity]
    activeEntities*: seq[int]
    domain: TDomain
    bbTree: TBBTree[int]
    host: enet.PHost
    ent_ID_counter: TIdgen[int]

proc newServ* : TServer =
  result.entities = @[]
  result.domain = newDomain()
  result.bbtree = newBBtree[int]()
  result.activeEntities = @[]


import algorithm
proc poll* (S: PServ) = 
  # poll enet
  if random(10) == 0:
    S.activeEntities.sort cmp[int]

proc get_ent* (S: PServ; id: int): PEntity{.inline.} = S.entities[id]

proc add_ent* (S: PServ; ent: TEntity): int =
  result = S.idg.get
  S.entities.ensureLen result+1
  S.entities[result] = ent
  S.get_ent(result).id = result
  S.activeEntities.add result
  S.bbtree.insert result, S.get_ent(result).getBoundingBox

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


when isMainModule:
  var server =   