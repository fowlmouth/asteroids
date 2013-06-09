import macros, enet_pkt_utils, strutils
import enet, fowltek/entitty
import lib/ast_comps

## TODO write enet_pkt_utils.writeBE[int] !
proc p* [T] (x: T): T =
  echo repr(x)
  return x

proc build_inner_peace (field, recd_list, read_body, write_body: PNimrodNode) {.compiletime.}=
  template thisTY: expr = ty[idx]
  recd_List.add field.copy
  for idx in 0 .. < <(< field.len ): # high - 2
    let thisName = $ field[idx]
    recd_list[< recd_list.len][idx] = thisName.ident.postFix("*")
  
    write_body.add "writeBE (buf, pkt.$1) ".
      format(thisName).#, repr(innerType)).#p.
      parseExpr
    
    read_body.add "readBE (pkt, result.$1)".
      format(thisName).#, repr(innerType)).
      parseExpr  


  discard """ template thisTY: expr = field[< < field.len] ## field.high - 1
  var innerType : PNimrodNode
  if thisTY.kind == nnkBracketExpr and thisTy[0].ident == !"seq":
    #innerType = thisTy[1][1]
    echo "INNER TYPE ", treerepr(innerType)
  else:
    innerType = thisTy
  
  echo treerepr(innertype) """
  

#macro defPacket* (pkt_name; ty; id): stmt {.immediate.} =
macro defPacket* : stmt {.immediate.} =  
  result = newStmtList()
  
  let 
    cs = callsite()
    pkt_name = $ cs[1]
    ty = cs[2]
  
  var 
    write_body = newStmtList()
    read_body = newStmtList() 
    pkt_ty = """type
      $1* = object""".format(pkt_name).parseExpr
  
  if len(cs) > 3:
    write_body.add newCall("writeCopy", "buf".ident, cs[3])
  
  ## turn the tuple[] into a type def and
  ## generate the bodies of the writing/reading functions 

  if ty.kind == nnkTupleTy:
    var recList = newNimNode(nnkRecList)
    
    for node in ty.children:
      build_inner_peace node, recList, read_body, write_body

    pkt_ty[0][2][2] = recList

  result.add pkt_ty

  var writeFunc = "proc writeBE* (buf: PBuffer; pkt: var $1) = nil".
    format(pkt_name).
    parseExpr
  if write_body.len > 0: writeFunc.body = write_body
  
  result.add writeFunc
  
  var readFunc = "proc readBE* (pkt: enet.PPacket; result: var $1) = nil".
    format(pkt_name).
    parseExpr
  if read_body.len > 0: readFunc.body = read_body
  
  result.add readFunc
  
  echo repr(result)


type
  TPacketHeader* = char

# s2c packets
defPacket SanityCheck, nil, 'a'

defPacket Welcome, tuple[
  serverName: string, numPlayers: int16, 
  numEntities: int16], 'b'
defPacket NotWelcomeHere, tuple[reason: string], 'c'
defPacket YourArenaIs, tuple[id: int32, name: string], 'd'

# c2s packets
defPacket componentRecd, tuple[
  name: string, size: int32]


defPacket hiThere, tuple[myName: string, components: seq[ComponentRecd]], 'A'

proc sendHiThere* (peer:PPeer; name: string) = 
  var pkt = hiThere(myName: name, components: newSeq[ComponentRecd](numComponents))
  #echo "numcomponents: ", numComponents
  
  echo "numcomponents: ", numcomponents
  for component in entitty.allComponents:
    echo "id ", component.id, " name: ", (if component.name.isNil: "NIL" else: component.name)
    pkt.components.add componentRecd(name: component.name, size: component.size.int32)
  
  var buf = newBuffer(128)
  buf.writeBE pkt
  if peer.send(0.cuchar, buf.toPacket(FlagReliable)) < 0:
    quit "omg fix me"


