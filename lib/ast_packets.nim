import macros, enet_pkt_utils, strutils
import enet, fowltek/entitty
import lib/ast_comps

## TODO write enet_pkt_utils.writeBE[int] !

proc p* [T] (x: T): T =
  echo repr(x)
  return x

var packetID_counter = 0

macro defPacket* (pkt_name; ty; id = -1): stmt {.immediate.} =
  discard """ var my_id = id.intval.int
  if my_id == -1:
    my_id = packetID_counter
    inc packetID_counter
   """
  
  result = newStmtList()
  
  var 
    write_body = newStmtList()#"writeCopy buf, $1". format(my_id). parseExpr
    read_body = newStmtList() 
    pkt_ty = """type
      $1* = object""".format(pkt_name).parseExpr
  
  ## turn the tuple[] into a type def and
  ## generate the bodies of the writing/reading functions 

  if ty.kind == nnkTupleTy:
    var recList = newNimNode(nnkRecList)
    
    for idx in 0 .. < ty.len:
      template thisTY: expr = ty[idx]
      let thisName = $ thisTy[0]
      recList.add thisTY.copy
      recList[< recList.len][0] = thisName.ident.postFix("*")
      
      var innerType : PNimrodNode
      if thisTy[1].kind == nnkBracketExpr and thisTy[1][0].ident == !"seq":
        
        #innerType = thisTy[1][1]
        echo "INNER TYPE ", treerepr(innerType)
        
      else:
        innerType = thisTy[1]
      
      echo treerepr(innertype)
      
      write_body.add "writebe(buf, pkt.$1) ".
        format(thisName, repr(innerType)).#p.
        parseExpr
      
      read_body.add "readbe(pkt, result.$1)".
        format(thisName, repr(innerType)).
        parseExpr

    pkt_ty[0][2][2] = recList

  var writeFunc = "proc writeBE* (buf: PBuffer; pkt: var $1) = nil".
    format(pkt_name).
    parseExpr
  if write_body.len > 0: writeFunc.body = write_body
  
  var readFunc = "proc readBE* (pkt: enet.PPacket; result: var $1) = nil".
    format(pkt_name).
    parseExpr
  if read_body.len > 0: readFunc.body = read_body
  
  result.add pkt_ty
  result.add writeFunc
  result.add readFunc
  echo repr(result)




# s2c packets
defPacket SanityCheck, nil

defPacket pktWelcome, tuple[yourID: int32]
defPacket pktNotWelcomeHere, tuple[reason: string]
defPacket pktYourArenaIs, tuple[id: int32, name: string]

# c2s packets
defPacket componentRecd, tuple[
  name: string, size: int32]

proc reportComponents (peer: PPeer) =
  var res: seq[componentRecd] = @[]
  
  for component in entitty.allComponents:
    res.add componentRecd(name: component.name, size: component.size.int32)
  
  var buf = newBuffer(512)
  buf.writeBE res
  

defPacket pktMyComponentsAre, tuple[components: seq[ComponentRecd]]

defPacket pktHiThere, tuple[myName: string]

