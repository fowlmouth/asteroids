import macros, enet_pkt_utils, strutils
import enet

## TODO write enet_pkt_utils.writeBE[int] !

macro defPacket* (pkt_name; ty): stmt {.immediate.} =
  
  result = newStmtList()
  
  var write_body = newStmtList(
    parse_expr("var buf = newBuffer(128)")
  )
  var read_body = newStmtList()
  
  ## turn the tuple[] into a type def
  ## also generate the bodies of the writing/reading functions 
  var pkt_ty = parseExpr("""type
  $1* = object""".format(pkt_name))
  if ty.kind == nnkTupleTy:
    var recList = newNimNode(nnkRecList)
    
    for idx in 0 .. < ty.len:
      template thisTY: expr = ty[idx]
      let thisName = $ thisTy[0]
      recList.add thisTY.copy
      recList[< recList.len][0] = thisName.ident.postFix("*")
      
      write_body.add parseExpr("buf.writeBE(pkt.$1)" % thisName)
      read_body.add  parseExpr("pkt.read(result.$1)" % thisName)

    pkt_ty[0][2][2] = recList
    
  var writeFunc = newProc(
    name = ident("write_" & $pkt_name).postfix("*"),
    params = [
      newEmptyNode(), #return type 
      newIdentDefs(   #arg 1
        ident("pkt"),
        newNimNode(nnkVarTy).add(pkt_name))
    ],
    body = write_body
  )
  
  var readFunc = newProc(
    name = ident("read_" & $pkt_name).postfix("*"),
    params = [
      pkt_name,
      newIdentDefs(
        ident("pkt"),
        parseExpr("enet.PPacket"))
    ],
    body = read_body
  )
  
  result.add pkt_ty
  result.add writeFunc
  result.add readFunc
  echo repr(result)
        
  
  

# s2c packets
defPacket pktWelcome, tuple[yourID: int32]
defPacket pktNotWelcomeHere, tuple[reason: string]
defPacket pktYourArenaIs, tuple[id: int32, name: string]

# c2s packets
defPacket pktHiThere, tuple[myName: string]

