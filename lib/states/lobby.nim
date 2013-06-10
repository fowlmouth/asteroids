import 
  lib/ast_gamestate, lib/ast_comps, 
  fowltek/entitty, fowltek/sdl2/engine, fowltek/vector_math
import_all_sdl2_modules

proc incY [A,B] (some: var TVector2[A]; by: B): TVector2[A] =
  some.y += by.A
  return some

proc lobbyInit (gs: PGameState) =
  
  var p = vec2f(100,100)
  
  # create some text
  var ent = gs.domain.newEntity(Pos, Text)
  ent[Pos] = p
  ent[Text] = Text(str: "herro")
  
  gs.add_local_entity ent 
  
  ent = gs.domain.newEntity(Pos, Text, Clickable)
  ent[Pos] = p.incY(10)
  ent[Text] = Text(str: "Play")
  ent[Clickable].cb = proc(X: PEntity) = 
    echo "nope"
  gs.add_local_entity ent

proc lobbyDraw* (gs: PGameState; R: PRenderer) =
  R.setDrawColor 0,0,0,255
  R.clear

  eachEntity(gs) do:
    entity.draw R


  R.present

proc lobbyUpdate* (gs: PGameState; dt: float) =
  eachEntity(gs) do:
    entity.update dt

var 
  lobbyVT_d = TGS_Vtable(update: lobbyUpdate, draw: lobbyDraw)
  lobbyVT* = lobbyVT_d.addr

proc lobbyState* : PGameState =
  new result 
  init result
  result.vt = lobbyVT
  result.lobbyInit

