## code that ties the component system to the main code in asteroids.nim

block :
  let winsize = NG.window.getSize
  ToroidalBounds.setInitializer proc(X: PEntity) =
    x[ToroidalBounds].rect.w = winSize.x
    x[ToroidalBounds].rect.h = winSize.y

Pos.setInitializer proc(X: PEntity) =
  X[Pos].x = random(640).float
  X[Pos].y = random(480).float

Orientation.setInitializer proc(X: PEntity)=
  X[Orientation].angleRad = random(360).float.degrees2radians

Vel.setInitializer proc(X: PEntity) =
  X[Vel].vec = random(360).float.degrees2radians.vectorForAngle * (1+(35* randf()))

SimpleAnim.setInitializer proc(X: PEntity) =
  var frame: ast_comps.TFrame
  frame.col = 0
  frame.time = 1000.0
  X[SimpleAnim].frames = @[frame]
  X[SimpleAnim].timer = 1000.0


msg_impl(ToroidalBounds, update) do (dt: float) :
  let p = entity[Pos].addr
  let R = entity[ToroidalBounds].rect.addr
  var warped = false
  template wt(body: stmt): stmt =
    warped = true
    body
  if p.x.cint < r.x:
    wt: p.x = r[].right.float
  elif p.x.cint > r[].right:
    wt: p.x = r.x.float
  if p.y.cint < R.y:
    wt: p.y = R[].bottom.float
  elif p.y.cint > R[].bottom:
    wt: p.y = R.y.float

  if warped:
    activeServer.bbtree.remove entity.id
    activeServer.bbtree.insert entity.id, entity.getBoundingBox 



## HID Dispatcher for sdl events

type
  T_HID_DispatchRec* = object
    takenBy: TMaybe[int]
    setup: proc(X: PEntity)
    name: string

  T_HID_Dispatcher* = object
    devices*: TTable[int, T_HID_DispatchRec]

var HID_Dispatcher*: T_HID_Dispatcher
HID_Dispatcher.devices =  initTable[int, T_HID_DispatchRec](8)

template HID_Device_Impl *(name_str: expr[string]; body: stmt): stmt {.immediate.} =
  block:
    var dev: T_HID_DispatchRec
    dev.name = name_str
    dev.setup = proc(X: PEntity) =
      body
      X[HID_Controller].name = name_str
    HID_Dispatcher.devices[name_str.deviceID] = dev


var HID_device_counter* : int
proc next_hid_id : int =
  result = HID_device_counter
  HID_device_counter.inc

proc deviceID* (name: expr[string]): int =
  var ID {.global.}: int = next_hid_id()
  return ID

proc hasDevice* (disp: var T_HID_Dispatcher;
      ID: int): bool =
  disp.devices.hasKey (ID)

proc requestDevice* (disp: var T_HID_Dispatcher; dev_name: expr[string]; 
    entity: PEntity): TMaybe[string] =
  
  let ID = deviceID(dev_name)
  
  if not disp.hasDevice(ID):
    return Just("Invalid device #$#" % $ID)
  
  if disp.devices[ID].takenBy:
    return Just("Device is already registered.")
  
  disp.devices[ID].setup(entity)
  disp.devices.mget(ID).takenBy = Just(entity.id)


proc handleEvent* (disp: var T_HID_Dispatcher; device: expr[string]; event: var sdl2.TEvent): bool =
  let ID = deviceID(device)
  if disp.hasDevice(ID) and disp.devices[ID].takenBy:  
    result = 
      activeServer.getEnt(disp.devices[ID].takenBy.val)[HID_Controller].cb(
        activeServer.getEnt(disp.devices[ID].takenBy.val), event)


HID_DeviceImpl("Mouse"):
  X[HID_Controller].cb = proc(X: PEntity; event: var TEvent): bool =
    if event.kind == mouseMotion:
      let m = evMouseMotion(event)
      X[pos].x = m.x.float
      x[pos].y = m.y.float
      result = true

HID_DeviceImpl("Keyboard"):
  #assert X.hasComponent(HID_Controller)
  X[HID_Controller].cb = proc(X: PEntity; event: var TEvent): bool=
    template rt(body: stmt): stmt = 
      body
      return true
    
    case event.kind
    of KeyDown:
      let k = evKeyboard(event)
      case k.keysym.sym
      of K_UP: 
        rt: X.thrust ThrustFwd
      of K_DOWN: 
        rt: X.thrust ThrustRev
      of K_LEFT: 
        rt: X.turn TurnLeft
      of K_RIGHT: 
        rt: X.turn TurnRight
      else: NIL
    of keyUp:
      let k = evKeyboard(event)
      case k.keysym.sym
      of K_UP: 
        rt: X.stopThrust ThrustFwd
      of K_Down: 
        rt: X.stopThrust  ThrustRev
      of K_Left: 
        rt: X.stopTurn TurnLeft
      of K_Right: 
        rt: X.stopTurn  TurnRight
      else:NIL
    else: nil




## helpful
proc drawDebugStrings (E: PEntity; R: PRenderer) =
  mlStringRGBA R, 10,10, E.debugStr, 0,190,190,255

