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
  

macro defPacket* (pkt_name; ty; id): stmt {.immediate.} =
  
  result = newStmtList()
  
  var 
    write_body = newStmtList(
      newCall("writeCopy", "buf".ident, id)
    )
    read_body = newStmtList() 
    pkt_ty = """type
      $1* = object""".format(pkt_name).parseExpr
  
  ## turn the tuple[] into a type def and
  ## generate the bodies of the writing/reading functions 

  if ty.kind == nnkTupleTy:
    var recList = newNimNode(nnkRecList)
    
    for idx in 0 .. < ty.len:
      build_inner_peace ty[idx], recList, read_body, write_body
      

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
defPacket SanityCheck, nil, 'a'

defPacket pktWelcome, tuple[
  serverName: string, numPlayers: int16, 
  numEntities: int16], 'b'
defPacket pktNotWelcomeHere, tuple[reason: string], 'c'
defPacket pktYourArenaIs, tuple[id: int32, name: string], 'd'

# c2s packets
defPacket componentRecd, tuple[
  name: string, size: int32], 'z'

proc reportComponents (peer: PPeer) =
  var res: seq[componentRecd] = @[]
  
  for component in entitty.allComponents:
    res.add componentRecd(name: component.name, size: component.size.int32)
  
  var buf = newBuffer(512)
  buf.writeBE res

defPacket pktHiThere, tuple[myName: string, components: seq[ComponentRecd]], 'A'

