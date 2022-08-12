import std/[
  macros
]

{.push used.}
proc defPushPop(stmtList: NimNode): NimNode =
  newStmtList(
    nnkPragma.newTree(
      ident "push",
      ident "used",
      ident "inline",
    ),
    stmtList,
    nnkPragma.newTree(
      ident "pop"
    )
  )


proc defMaybeExportedIdent(id: NimNode, public: bool): NimNode =
  if public:
    nnkPostfix.newTree(
      ident "*",
      id
    )
  else:
    id

proc defWithType(name: NimNode): NimNode =
  result = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      name,
      nnkGenericParams.newTree(
        nnkIdentDefs.newTree(
          newIdentNode("T"),
          newEmptyNode(),
          newEmptyNode()
        )
      ),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        nnkRecList.newTree(
          nnkIdentDefs.newTree(
            newIdentNode("value"),
            newIdentNode("T"),
            newEmptyNode()
          )
        )
      )
    )
  )


macro maybePublic(public: static[bool], body: untyped): untyped =
  if not public:
    result = body
  else:
    result = newStmtList()

    for element in body:
      if element.kind notin {nnkProcDef, nnkIteratorDef}:
        result.add element
      else:
        element[0] = nnkPostfix.newTree(
          ident "*",
          element[0]
        )
        result.add element
{.pop.}