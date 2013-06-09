import lib/ast_comps, lib/ast_serv
import fowltek/entitty, fowltek/sdl2/engine
import os, fowltek/idgen, fowltek/vector_math, strutils
import math, tables, fowltek/tmaybe, fowltek/bbtree
import_all_sdl2_modules
randomize()

setImageRoot getAppDir()/"gfx"

var NG =  newSdlEngine()

var activeServer: TCServ

include lib/ast_boilerplate

var 
  localPlayerID = -1
  mouseEntID = -1

template ENT (id): expr = activeServer.getEnt(id)
template localPlayer:expr = activeServer.get_ent(localPlayerID)

const Asteroids = [
  "Rock24b_24x24.png",  
  "Rock48b_48x48.png",
  "Rock64b_64x64.png",
  "Meteor_32x32.png",
  "Rock32a_32x32.png",
  "Rock48c_48x48.png",
  "Rock64c_64x64.png",
  "Rock24a_24x24.png",
  "Rock48a_48x48.png",
  "Rock64a_64x64.png"]

proc init_random_asteroid (X: PEntity)= 
  X.loadSimpleAnim NG, Asteroids[random(Asteroids.len)]
  X[BoundingCircle] = BoundingCircle(radius: X[SpriteInst].sprite.center.x.float)

proc add_asteroids (S: PCServ, num = 10) =
  S.add_ents(
    num,
    Pos, Vel, SpriteInst, SimpleAnim, ToroidalBounds, Health, BoundingCircle
  ).each_ent_cb(
    S,
    init_random_asteroid
  )

type
  TClient* = object
    


proc connect* (address: string; port: int): TMaybe[TClient]=
  nil

proc newLocalServ* : TClient =
  nil  

proc initialize_local_game (
    ast_count = (if paramCount() == 1: paramStr(1).parseInt.int else: 10)
  ) =
  activeServer = newServ()

  activeServer.add_asteroids ast_count

  localPlayerID = activeServer.add_ent(activeServer.domain.newEntity(Pos, Vel, SpriteInst, ToroidalBounds, 
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
    echo "Could not register mouse: ", err.val
  

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
  
  activeServer.poll
  
  if not paused:
    activeServer.update dt

    if localPlayerID != -1:
      collisions.setLen 0
      activeServer.bbtree.collectCollisions localPlayerID, collisions

    NG.setDrawColor 0,0,0,255
    NG.clear

    eachEntity(activeServer):
      entity.draw NG

    LocalPlayer.drawDebugStrings NG

    if debugDrawEnabled:
      eachEntity(activeServer):
        entity.debugDraw NG
      activeServer.bbtree.debugDraw NG

    for ID in collisions:
      let p = vec2s(ID.ent[pos])
      NG.circleRGBA p.x,p.y, 20, 0,0,255,255      
  
  NG.present

destroy NG



