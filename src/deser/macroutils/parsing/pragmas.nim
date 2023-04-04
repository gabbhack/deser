discard """
  action: "compile"
"""
{.experimental: "caseStmtMacros".}

import std/[
  macros
]

# for pattern matching and assertKind
import deser/macroutils/matching


iterator parsePragma*(pragmas: NimNode): (NimNode, seq[NimNode]) =
  ## Parse `nnkPragma` node and return tuple with pragma symbol and pragma values.
  runnableExamples:
    import std/[macros]
  
    template test(a: int) {.pragma.}
  
    macro run() =
      let pragma = nnkPragma.newTree(
        newCall(
          bindSym"test",
          newLit 123
        )
      )

      for sym, values in pragma.parsePragma:
        doAssert sym == bindSym"test"
        doAssert values == @[newLit 123]
    
    run()

  assertKind pragmas, {nnkPragma}

  for pragma in pragmas:
    case pragma:
    of Sym():
      # {.pragmaName.}
      yield (pragma, @[])
    of Call[@sym, all @values] | ExprColonExpr[@sym, all @values]:
      # {.pragmaName(values).}
      # or
      # {.pragmaName: value.}
        yield (sym, values)
    of Ident():
      discard "process only typed nodes"
    else:
      assertKind pragma, {nnkSym, nnkCall, nnkExprColonExpr, nnkIdent}
