import fowltek/entitty
import fowltek/TMaybe, math, fowltek/vector_math, fowltek/boundingbox
import fowltek/sdl2/engine

import_all_sdl2_modules
import_all_sdl2_helpers

type TVector2f* = TVector2[float]

template vec_accessor (name; ty): stmt {.immediate.} =
  proc `vec2 name`* [A: TNumber] (some: TVector2[A]): TVector2[ty] = (some.x.ty,some.y.ty)
  proc `vec2 name`* [A: TNumber] (x,y: A): TVector2[ty] = (x.ty, y.ty)

vec_accessor f, float
vec_accessor s, int16

const
  TAU = PI * 2
  HalfPI = PI/2


proc debugSTR* (result: var seq[string]) {.multicast.}
proc debugSTR* (entity: PEntity): seq[string] =
  newseq result, 0
  entity.debugStr result
template debug_str_impl(ty; body: stmt): stmt {.immediate.}=
  msg_impl(ty, debugSTR) do (result: var seq[string]):
    body

template default_debug_str(ty): stmt {.immediate.} =
  debugStrImpl(ty):
    result.add("$1: $2".format(componentInfo(ty).name, $ entity[ty]))

proc debugDRAW* (R: PRenderer) {.multicast.}
template debugDrawImpl (ty; body: stmt): stmt {.immediate.}=
  msg_impl(ty, debugDRAW) do(R: PRenderer) :
    body


proc update* (dt: float) {.multicast.}
proc getPos* : TVector2f {.unicast.}
proc draw* (R: PRenderer) {.unicast.}

proc getBoundingBox* : TBB {.unicast.}

template ff (f; prec = 5): expr = formatFloat(f, ffDecimal, prec)

proc `$`* (some: TVector2f): string = "($1, $2)" % [
  ff(some.x, 4), 
  ff(some.y, 4)]




type
  Pos* = TVector2f
msg_impl(Pos, get_pos) do -> TVector2f: 
  result = entity[Pos]
default_debug_str Pos

type
  Vel* = object
    vec*: TVector2f

msg_impl(Vel, update) do (dt: float):
  entity[Pos] += entity[Vel].vec * dt

msg_impl(Vel, debugSTR) do(result:var seq[string]):
  result.add "Vel: $1" % $entity[Vel].vec


type
  SpriteInst* = object
    sprite*: PSprite
    rect*: TRect
SpriteInst.requiresComponent Pos

debugStrImpl(SpriteInst):
  result.add "Sprite: $1" % entity[SpriteInst].sprite.file
  
msg_impl(SpriteInst, getBoundingBox) do -> TBB:
  let p = entity[Pos].addr
  return bb(
    p.x - (entity[SpriteInst].rect.w / 2), 
    p.y - (entity[SpriteInst].rect.h / 2), 
    entity[SpriteInst].rect.w.float, 
    entity[SpriteInst].rect.h.float)

msg_impl(SpriteInst, draw) do (R: PRenderer):
  #something
  var dest = entity[SpriteInst].rect
  let p = entity[Pos].addr
  dest.x = p.x.cint - (entity[SpriteInst].rect.w / 2).cint
  dest.y = p.y.cint - (entity[SpriteInst].rect.h / 2).cint
  R.copy entity[SpriteInst].sprite.tex, 
    entity[SpriteInst].rect.addr, dest.addr  


var imageCache* = newSpriteCache(64)
proc setImageRoot* (dir: string) {.inline.} = 
  imagecache.setImageRoot(dir)

proc loadSprite* (s: var SpriteInst, R: PRenderer; file: string) =
  s.sprite = imagecache.get(R, file)
  s.rect = s.sprite.defaultRect


type
  TFrame* = tuple[col: int, time: float] 
  SimpleAnim* = object
    frames*: seq[TFrame]
    curFrame*: int
    timer*: float
SimpleAnim.requiresComponent SpriteInst

debugStrImpl(SimpleAnim): 
  result.add "SimpleAnim: frame $1/$2".format(
    entity[SimpleAnim].curFrame, entity[SimpleAnim].frames.len)

proc randf* (prec = 10_000): float {.inline.}= random(prec)/prec

proc loadSimpleAnim* (ent: PEntity; R: PRenderer; file: string) =
  ent[SpriteInst].loadSprite R, file
  ent[SimpleAnim].timer = 0.2
  newSeq ent[SimpleAnim].frames, ent[SpriteInst].sprite.cols

  for i in 0 .. <ent[SpriteInst].sprite.cols:
    ent[SimpleAnim].frames[i].col = i
    ent[SimpleAnim].frames[i].time = (randf() * 0.3) + 0.1

msg_impl(SimpleAnim, update) do (dt: float): 
  entity[SimpleAnim].timer -= dt
  if entity[SimpleAnim].timer <= 0:
    let frameIndex = (entity[SimpleAnim].curFrame+1) mod entity[SimpleAnim].frames.len
    entity[SimpleAnim].curFrame = frameIndex
    entity[SimpleAnim].timer = entity[SimpleAnim].frames[frameIndex].time
    entity[SpriteInst].rect.x =cint(
      entity[SpriteInst].rect.w * entity[SimpleAnim].frames[frameIndex].col )



type
  ToroidalBounds* = object
    rect*: TRect
ToroidalBounds.requiresComponent pos

debugStrImpl(ToroidalBounds): 
  result.add "Bounded to: $#".format(entity[ToroidalBounds].rect)

proc right* (some: TRect): cint = some.x + some.w
proc bottom*(some: TRect): cint = some.y + some.h
#ToroidalBounds#update in ast_boilerplate

type
  Orientation* = object
    angleRad*: float
debugStrImpl(Orientation):
  result.add "Orientation: $# degrees" % entity[Orientation].angleRad.radians2degrees.formatFloat(ffDecimal, 2)
debugDrawImpl(Orientation):
  let offs = entity[Orientation].angleRad.vectorForAngle * 10.0
  let p = entity[Pos].addr
  R.lineRGBA p.x.int16, p.y.int16, (p.x + offs.x).int16, (p.y + offs.y).int16,
    0,255,0,255

type
  Acceleration* = object
    vec: TVector2f
Acceleration.requiresComponent Vel

debugStrImpl(Acceleration):
  result.add "Accel angle: $# magnitude: $#" % [
    ff(entity[Acceleration].vec.vectorToAngle.radians2degrees, 2),
    ff(entity[Acceleration].vec.length, 4) ]

msg_impl(Acceleration, update) do (dt: float):
  entity[Vel].vec += entity[Acceleration].vec
  entity[Acceleration].vec *= 0.92
  #reset entity[Acceleration].vec



type
  TThrustState* = enum ThrustIdle, ThrustFwd, ThrustRev
  TTurningState* = enum TurnIdle, TurnRight, TurnLeft
  InputState* = object
    thrust*: TThrustState
    turning*: TTurningState
InputState.requiresComponent Acceleration, Orientation
defaultDebugStr InputState

proc turn* (dir: TTurningState) {.unicast.}
proc stopTurn* (dir: TTurningState) {.unicast.}
proc thrust* (dir: TThrustState) {.unicast.}
proc stopThrust* (dir: TThrustState) {.unicast.}

proc roll* (dir: TTurningState) {.unicast.}


msg_impl(InputState, turn) do (dir: TTurningState):
  entity[InputState].turning = dir
msg_impl(InputState, stopTurn) do (dir: TTurningState):
  if entity[InputState].turning == dir:
    entity[InputState].turning = TurnIdle
msg_impl(InputState, thrust) do (dir: TThrustState):
  entity[InputState].thrust = dir
msg_impl(InputState, stopThrust) do (dir: TThrustState):
  if entity[InputState].thrust == dir:
    entity[InputState].thrust = ThrustIdle
msg_impl(InputState, update) do (dt: float): 
  case entity[InputState].thrust
  of ThrustFwd:
    entity[Acceleration].vec = entity[Orientation].angleRad.vectorForAngle * 2.0 
  of ThrustRev:
    entity[Acceleration].vec = entity[Orientation].angleRad.vectorForAngle * -2.0 
  else: nil
  case entity[InputState].turning
  of TurnRight:
    entity[Orientation].angleRad += 7.0 * dt
    entity.roll TurnRight
  of TurnLeft:
    entity[Orientation].angleRad -= 7.0 * dt
    entity.roll TurnLeft
  else:nil

type
  InputController* = object of TObject

  HID_Controller* = object of InputController
    name*: string
    cb*: proc(X: PEntity; event: var TEvent): bool

 
HID_Controller.setInitializer proc(X: PEntity) =
  X[HID_Controller].name = "Disconnected"
  X[HID_Controller].cb = proc(X: PEntity; event: var TEvent): bool = false

debugStrImpl(HID_Controller):
  result.add "HID Controller: $#" % entity[HID_Controller].name


type
  BoundingCircle* = object
    radius*: float
BoundingCircle.requiresComponent Pos

msg_impl(BoundingCircle, getBoundingBox, 1001) do -> TBB:
  let (p, r) = (entity[Pos].addr, entity[BoundingCircle].radius)
  result = bb(p.x - r, p.y - r, r * 2, r * 2)

defaultDebugStr BoundingCircle
debugDrawImpl BoundingCircle:
  let p = entity[Pos].vec2s
  R.circleRGBA p.x, p.y, entity[BoundingCircle].radius.int16, 
    0,255,0,255


# RollSprite are the fake-3d sprites like the ship sprites (rotation angles are rows)
type
  RollSprite* = object
    roll: float
RollSprite.requiresComponent SpriteInst
debugStrImpl(RollSprite):
  result.add "Roll: $#" % formatFloat(entity[RollSprite].roll,ffDecimal,2)

msg_impl(RollSprite, update) do (dt: float):
  entity[RollSprite].roll *= 0.98
  
proc p* [T] (some: T): T = 
  some.repr.echo
  return some

proc p_chance* [T] (some: T): T =
  if random(100) < 10: some.repr.echo
  return some

msg_impl(RollSprite, draw, 1000) do (R: PRenderer):
  var dest = entity[SpriteInst].rect
  let p = entity[Pos].addr
  dest.x = (p.x - (dest.w/2)).cint
  dest.y = (p.y - (dest.h/2)).cint
  # set the row/col of the src rect
  # i want -1 to be 0 and 1 to be sprite.cols
  
  # so i take roll (it goes from -1 to 1), add 1 to it, divide by 2 
  # multiply by how many cols there are
  entity[SpriteInst].rect.x = (
    (entity[RollSprite].roll + 1.0) / 2.0 * entity[SpriteInst].sprite.cols.float
  ).floor.cint * entity[SpriteInst].rect.w
  entity[SpriteInst].rect.y = (
    (entity[Orientation].angleRad + HalfPI).radians2degrees / #radians2degrees because it does `mod 360` 
    360.0 * 
    entity[SpriteInst].sprite.rows.float
  ).floor.cint * entity[SpriteInst].rect.h 
  
  R.copy entity[SpriteInst].sprite.tex, entity[SpriteInst].rect.addr, dest.addr

msg_impl(RollSprite, roll) do (dir: TTurningState):
  case dir
  of TurnRight:
    entity[RollSprite].roll -= 0.2
    if entity[RollSprite].roll < -1: entity[RollSprite].roll = -1
  of TurnLeft:
    entity[RollSprite].roll += 0.2
    if entity[RollSprite].roll > 1: entity[RollSprite].roll = 1
  else:nil



proc die* {.unicast.}
proc takeHealth*(amount: int) {.unicast.}

type
  Health* = object
    hp, max: int
  Immortal* = object

msg_impl(Health, takeDamage) do (amount: int):
  entity[Health].hp -= amount
  if entity[Health].hp <= 0: entity.die
defaultDebugStr(Health)

msg_impl(Immortal, takeDamage) do(amount: int):
  nil
defaultDebugStr(Immortal)

type
  DebugShape* = ref object{.inheritable.}
    draw*: proc(X: PEntity; R: PRenderer)
  
  PDebugCircle = ref object of DebugShape
    radius: float

DebugShape.setInitializer do (X: PEntity): 
  X[DebugShape] = DebugShape(draw: proc(X: PEntity; R: PRenderer) = nil)
  
msg_impl(DebugShape, draw) do (R: PRenderer):
  entity[DebugShape].draw entity, R

proc debugCircle* (radius: float): DebugShape = PDebugCircle(
    radius: radius,
    draw: proc(X: PEntity, R: PRenderer) =
      let p = X[pos].addr
      R.circleRGBA p.x.int16, p.y.int16, X[DebugShape].PDebugCircle.radius.int16,
        0,255,0,255   
  ).DebugShape


type
  Named* = object
    name: string







