discard """
  action: "compile"
"""
import std/[
  macros,
  options
]

from deser/macroutils/types as macro_types import
  TypeInfo,
  initTypeInfo,
  recList,
  pragma,

  Struct,
  initStruct,
  genericParams,

  StructFeatures,
  initStructFeatures,
  initEmptyStructFeatures,

  Field,
  isCase,
  branches,
  public,
  features,
  fields,
  aliases,
  renameSerialize,
  renameDeserialize,
  `skipSerializing=`,
  `skipDeserializing=`,
  `renameSerialize=`,
  `renameDeserialize=`,
  `defaultValue=`

import deser/macroutils/matching
import deser/macroutils/parsing/struct
import deser/pragmas


template test() {.pragma.}

type 
  First {.test.} = object of RootObj
    id: int

  Second = object of First
    text: string

  Third = ref object of Second

  Fourth[T] = object

  Fifth {.onUnknownKeys(test), renameAll(CamelCase), skipPrivate, defaultValue.} = object

macro run() =
  let
    firstTypeDef = First.getTypeInst().getImpl()
    secondTypeDef = Second.getTypeInst().getImpl()

    firstObjectTy = firstTypeDef[2]
    secondObjectTy = secondTypeDef[2]

    firstRecList = firstObjectTy[2]
    secondRecList = secondObjectTy[2]

  block:
    let
      mergedRecList = mergeRecList(firstRecList, secondRecList)
      checkRecList = nnkRecList.newTree(
        nnkIdentDefs.newTree(
          ident "id",
          bindSym "int",
          newEmptyNode()
        ),
        nnkIdentDefs.newTree(
          ident "text",
          bindSym "string",
          newEmptyNode()
        )
      )

    doAssert mergedRecList == checkRecList, mergedRecList.treeRepr()
  
  block:
    doAssertRaises(AssertionDefect):
      discard mergeRecList(newEmptyNode(), nnkRecList.newTree())
    
    doAssertRaises(AssertionDefect):
      discard mergeRecList(nnkRecList.newTree(), newEmptyNode())

  block:
    let typeInfo = Typeinfo.fromTypeSym(First.getTypeInst())

    doAssert typeInfo.recList.get() == nnkRecList.newTree(
      nnkIdentDefs.newTree(
        ident "id",
        bindSym "int",
        newEmptyNode()
      )
    ), typeInfo.recList.get().treeRepr()
  
  block:
    let typeInfo = Typeinfo.fromTypeSym(Second.getTypeInst())

    doAssert typeInfo.recList.get() == nnkRecList.newTree(
      nnkIdentDefs.newTree(
        ident "id",
        bindSym "int",
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident "text",
        bindSym "string",
        newEmptyNode()
      )
    ), typeInfo.recList.get().treeRepr()
  
  block:
    let typeInfo = Typeinfo.fromTypeSym(Third.getTypeInst())

    doAssert typeInfo.recList.get() == nnkRecList.newTree(
      nnkIdentDefs.newTree(
        ident "id",
        bindSym "int",
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident "text",
        bindSym "string",
        newEmptyNode()
      )
    ), typeInfo.recList.get().treeRepr()

  block:
    let typeInfo = Typeinfo.fromTypeSym(Fourth.getTypeInst())

    doAssert typeInfo.recList.isNone

  block:
    let
      firstType = Typeinfo.fromTypeSym(First.getTypeInst())
      fourthType = Typeinfo.fromTypeSym(Fourth.getTypeInst())

    doAssert firstType.genericParams.isNone
    assertKind fourthType.genericParams.get()[0], {nnkSym}
  
  block:
    let
      firstType = Typeinfo.fromTypeSym(First.getTypeInst())
      fourthType = Typeinfo.fromTypeSym(Fourth.getTypeInst())

    doAssert firstType.pragma.get()[0] == bindSym "test", firstType.pragma.get().treeRepr()
    doAssert fourthType.pragma.isNone

  block:
    let 
      firstType = Typeinfo.fromTypeSym(First.getTypeInst())
      fifthType = Typeinfo.fromTypeSym(Fifth.getTypeInst())

    doAssert StructFeatures.fromPragma(firstType.pragma) == initEmptyStructFeatures()

    doAssert StructFeatures.fromPragma(fifthType.pragma) == initStructFeatures(
      onUnknownKeys=some bindSym "test",
      renameAll=some bindSym "CamelCase",
      skipPrivateSerializing=true,
      skipPrivateDeserializing=true,
      defaultValue=some newEmptyNode()
    ), $StructFeatures.fromPragma(fifthType.pragma)

  block:
    doAssertRaises(AssertionDefect):
      discard StructFeatures.fromPragma(some newEmptyNode())

run()