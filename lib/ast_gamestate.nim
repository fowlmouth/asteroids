import
  fowltek/entitty, fowltek/sdl2, fowltek/idgen,
  lib/ast_comps
type 
  PGameState* = ref object of TObject
    entities*: seq[TEntity]
    activeEntities*: seq[int] 
    vt*: ptr TGS_Vtable 
    domain*: TDomain
    idg: TIDgen[int]
  
  TGS_VTable* = object
    update*: proc(gs: PGameState; dt: float)
    draw*: proc(gs: PGameState; R: sdl2.PRenderer)


proc update* (some: PGameState; dt: float){.inline.} = some.vt.update(some, dt)
proc draw* (some: PGameState; R: PRenderer) {.inline.} = some.vt.draw(some, R)

proc updateNOP(gs:PGameState; dt:float) = nil
proc drawNOP(gs: PGameState; R: Prenderer) = nil
var 
  default_VT_d = TGS_Vtable(update: updateNOP, draw: drawNOP)
  default_VT* = default_VT_d.addr

proc init* (some: PGameState) =
  newSeq some.entities, 2048
  newSeq some.activeEntities, 0
  some.vt = default_VT
  some.domain = newDomain()
  some.idg = newIDgen[int]()

template EachEntity* (gs; body: stmt): stmt {.immediate.} =
  for i in gs.activeEntities:
    template entity : expr = gs.entities[i]
    body


proc add_local_entity* (gs: PGameState; ent: TEntity): int {.discardable.}=
  result = gs.idg.get
  gs.entities.ensureLen result+1
  gs.entities[result] = ent
  gs.entities[result].id = result
  gs.activeEntities.add result



