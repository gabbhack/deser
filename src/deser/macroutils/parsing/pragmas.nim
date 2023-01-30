discard """
  action: "compile"
"""
{.experimental: "caseStmtMacros".}

when isMainModule:
  import std/[
    enumerate,
    tables
  ]

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

when isMainModule:
  template test(a = 123, b = 123) {.pragma.}
  template foo() {.pragma.}

  type Test = object
    first {.test.}: int
    second {.test().}: int
    third {.test: 123.}: int
    fourth {.test(123, 321).}: int
    fifth {.foo.}: int
    sixth {.test, test(), test: 123, test(123, 321), foo, foo().}: int

  macro run() =
    let recList = Test.getTypeInst().getImpl()[2][2]
    assertKind recList, {nnkRecList}
    
    for identDef in recList:
      let
        fieldName = identDef[0][0].strVal
        pragma = identDef[0][1]

      let checks =
        block:
          let
            emptyValues = newSeqOfCap[NimNode](0)
            defaultTestValues = @[newLit 123, newLit 123]
            testSym = bindSym"test"
            fooSym = bindSym"foo"

          case fieldName
          of "first", "second":
            {0: (testSym, defaultTestValues)}.toTable
          of "third":
            {0: (testSym, defaultTestValues)}.toTable
          of "fourth":
            {0: (testSym, @[newLit 123, newLit 321])}.toTable
          of "fifth":
            {0: (fooSym, emptyValues)}.toTable
          of "sixth":
            {
              0: (testSym, defaultTestValues),
              1: (testSym, defaultTestValues),
              2: (testSym, defaultTestValues),
              3: (testSym, @[newLit 123, newLit 321]),
              4: (fooSym, emptyValues),
              5: (fooSym, emptyValues)
            }.toTable
          else:
            raise newException(ValueError, "Unknown field")

      for num, (sym, values) in enumerate(pragma.parsePragma):
        let (checkSym, checkValues) = checks[num]
        doAssert sym == checkSym
        doAssert values == checkValues

  run()
