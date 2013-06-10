## HID Dispatcher for sdl events
import 
  fowltek/tmaybe,fowltek/entitty

type
  T_HID_DispatchRec* = object
    takenBy*: TMaybe[int]
    setup*: proc(X: PEntity)
    name*: string

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
