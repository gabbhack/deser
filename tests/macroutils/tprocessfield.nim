discard """
  action: "compile"
"""
import std/[macros, options]

import deser/macroutils/types
import deser/macroutils/processing/field


type Test = object

macro run =
  block:
    var
      emptyBranch = initFieldBranch(
        fields=newSeqOfCap[Field](0),
        conditionOfBranch=some nnkOfBranch.newTree()
      )

      nestedField = initField(
        nameIdent=ident"nested",
        typeNode=bindSym"Test",
        features=initEmptyFieldFeatures(),
        public=false,
        isCase=true,
        branches=(@[emptyBranch, emptyBranch])
      )

      firstFieldBranches = @[
        emptyBranch,
        initFieldBranch(
          fields=(@[nestedField]),
          conditionOfBranch=some nnkOfBranch.newTree()
        )
      ]

      firstField = initField(
        nameIdent=ident"first",
        typeNode=bindSym"Test",
        features=initEmptyFieldFeatures(),
        public=false,
        isCase=true,
        branches=firstFieldBranches
      )

      secondField = initField(
        nameIdent=ident"second",
        typeNode=bindSym"Test",
        features=initEmptyFieldFeatures(),
        public=false,
        isCase=true,
        branches=(@[emptyBranch, emptyBranch])
      )
    
    firstField.mergeToAllBranches(secondField)

    #[
    BEFORE:

    type Some = object
      case first: Test
      of ...:
        discard
      of ...:
        case nested: Test
        of ...:
          discard
        of ...:
          discard
      
      case second: Test
      of ...:
        discard
      of ...:
        discard
    
    AFTER:
    
    type Some = object
      case first: Test
      of ...:
        case second: Test
        of ...:
          discard
        of ...:
          discard
      of ...:
        case nested: Test
        of ...:
          case second: Test
          of ...:
            discard
          of ...:
            discard
        of ...:
          case second: Test
          of ...:
            discard
          of ...:
            discard
    ]#
    doAssert firstField.branches[0].fields[0].nameIdent == ident"second"
    doAssert firstField.branches[1].fields.len == 1
    doAssert firstField.branches[1].fields[0].branches[0].fields[0].nameIdent == ident"second"
    doAssert firstField.branches[1].fields[0].branches[1].fields[0].nameIdent == ident"second"

run()
