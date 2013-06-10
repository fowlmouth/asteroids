import
  fowltek/entitty, fowltek/sdl2, fowltek/idgen,fowltek/sdl2/engine, 
  fowltek/tmaybe,
  lib/ast_comps, lib/input_dispatcher
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
    poll*: Proc(gs: PGameState; NG: PSdlEngine; keepRunning: var bool)


proc update* (some: PGameState; dt: float){.inline.} = some.vt.update(some, dt)
proc draw* (some: PGameState; R: PRenderer) {.inline.} = some.vt.draw(some, R)

proc updateNOP(gs:PGameState; dt:float) = nil
proc drawNOP(gs: PGameState; R: Prenderer) = nil
proc pollNOP (gs: PGameState; NG: PSdlEngine; keepRunning: var bool) {.procvar.}=  
  while NG.pollHandle: nil

proc gsVT* (draw = drawNOP, update = updateNOP, poll = pollNOP): TGS_Vtable =
  TGS_VTable(draw: draw, update: update, poll: poll)

var 
  default_VT_d = gsVT()
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



proc handleEvent* (disp: var T_HID_Dispatcher; GS: PGameState; device: expr[string]; event: var sdl2.TEvent): bool =
  let ID = deviceID(device)
  if disp.hasDevice(ID) and disp.devices[ID].takenBy:
    let E_ID = disp.devices[ID].takenBy.val  
    result = 
      GS.entities[E_ID][HID_Controller].cb(
        GS.entities[E_ID], event)
  #    ENT(disp.devices[ID].takenBy.val)[HID_Controller].cb(
  #      ENT(disp.devices[ID].takenBy.val), event)

proc poll* (GS: PGameState; NG: PSdlEngine; keepRunning: var bool) {.inline.} = 
  GS.vt.poll(GS, NG, keepRunning)
  
proc poll_HID_Dispatch* (GS: PGameState; NG: PSdlEngine; keepRunning: var bool) =
  while NG.pollHandle:
    case NG.evt.kind
    of QuitEvent: 
      keepRunning = false
      break
    of KeyDown:
      if not HID_Dispatcher.handleEvent(GS, "Keyboard", NG.evt):# or paused:
        let k = NG.evt.evKeyboard.keysym.sym
        case k
        of K_ESCAPE: keepRunning = false
        of K_D: nil#debugDrawEnabled = not debugDrawEnabled
        else:nil
    of keyUp:
      #if not paused:
      discard HID_Dispatcher.handleEvent(GS, "Keyboard", NG.evt)
    of MouseMotion, MouseButtonDown, MouseButtonUp, MouseWheel:
      #if not paused: 
      discard HID_Dispatcher.handleEvent(GS, "Mouse", NG.evt)
    else:nil


