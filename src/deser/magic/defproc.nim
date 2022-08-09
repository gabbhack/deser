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
{.pop.}