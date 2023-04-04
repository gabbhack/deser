discard """
  action: "compile"
"""
import std/[macros, options]

import deser/macroutils/types
import deser/pragmas


type Test = object

macro run =
  block:
    doAssertRaises(AssertionDefect):
      discard initStruct(
        typeSym=ident"Test",
        fields=newSeqOfCap[Field](0),
        features=initEmptyStructFeatures(),
        genericParams=none NimNode
      )

    doAssertRaises(AssertionDefect):
      discard initStruct(
        typeSym=ident"Test",
        fields=newSeqOfCap[Field](0),
        features=initEmptyStructFeatures(),
        genericParams=some newStmtList()
      )

  block:
    doAssertRaises(AssertionDefect):
      discard initField(
        nameIdent=newStmtList(),
        typeNode=bindSym"Test",
        features=initEmptyFieldFeatures(),
        public=false,
        isCase=false,
        branches=newSeqOfCap[FieldBranch](0)
      )

    doAssertRaises(AssertionDefect):
      discard initField(
        nameIdent=ident"Test",
        typeNode=newStmtList(),
        features=initEmptyFieldFeatures(),
        public=false,
        isCase=false,
        branches=newSeqOfCap[FieldBranch](0)
      )
    
    doAssertRaises(AssertionDefect):
      let field = initField(
        nameIdent=ident"Test",
        typeNode=bindSym"Test",
        features=initEmptyFieldFeatures(),
        public=false,
        isCase=false,
        branches=newSeqOfCap[FieldBranch](0)
      )
      discard branches(field)

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
    
    firstField.merge(secondField)

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

  block:      
    doAssertRaises(AssertionDefect):
      discard initFieldBranch(
        fields=newSeqOfCap[Field](0),
        conditionOfBranch=some newStmtList()
      )
    
    doAssertRaises(AssertionDefect):
      let branch = initFieldBranch(
        fields=newSeqOfCap[Field](0),
        conditionOfBranch=none NimNode
      )

      discard conditionOfBranch(branch)

    discard initFieldBranch(
      fields=newSeqOfCap[Field](0),
      conditionOfBranch=none NimNode
    )
  
  block:
    doAssertRaises(AssertionDefect):
      discard initTypeInfo(
        typeSym=ident"Test",
        pragma=none NimNode,
        recList=none NimNode,
        genericParams=none NimNode
      )
    
    doAssertRaises(AssertionDefect):
      discard initTypeInfo(
        typeSym=bindSym"Test",
        pragma=some newEmptyNode(),
        recList=none NimNode,
        genericParams=none NimNode
      )
    
    doAssertRaises(AssertionDefect):
      discard initTypeInfo(
        typeSym=bindSym"Test",
        pragma=none NimNode,
        recList=some newEmptyNode(),
        genericParams=none NimNode
      )
    
    doAssertRaises(AssertionDefect):
      discard initTypeInfo(
        typeSym=bindSym"Test",
        pragma=none NimNode,
        recList=none NimNode,
        genericParams=some newEmptyNode()
      )

    discard initTypeInfo(
      typeSym=bindSym"Test",
      pragma=none NimNode,
      recList=none NimNode,
      genericParams=none NimNode
    )
  
  block:
    let fields = @[
      initField(
        nameIdent=ident "First",
        typeNode=bindSym "Test",
        features=initEmptyFieldFeatures(),
        public=false,
        isCase=false,
        branches=newSeqOfCap[FieldBranch](0)
      ),
      initField(
        nameIdent=ident "Second",
        typeNode=bindSym "Test",
        features=initEmptyFieldFeatures(),
        public=false,
        isCase=true,
        branches = @[
          initFieldBranch(
            fields = @[
              initField(
                nameIdent=ident "Third",
                typeNode=bindSym "Test",
                features=initEmptyFieldFeatures(),
                public=false,
                isCase=false,
                branches=newSeqOfCap[FieldBranch](0)
              ),
              initField(
                nameIdent=ident "Nope",
                typeNode=bindSym "Test",
                features=initFieldFeatures(
                  skipSerializing=false,
                  skipDeserializing=false,
                  untagged=true,
                  renameSerialize=none NimNode,
                  renameDeserialize=none NimNode,
                  skipSerializeIf=none NimNode,
                  serializeWith=none NimNode,
                  deserializeWith=none NimNode,
                  defaultValue=none NimNode,
                  aliases = @[],
                  deserWith=none NimNode
                ),
                public=false,
                isCase=true,
                branches = @[
                  initFieldBranch(
                    fields = @[
                      initField(
                        nameIdent=ident "Fourth",
                        typeNode=bindSym "Test",
                        features=initEmptyFieldFeatures(),
                        public=false,
                        isCase=false,
                        branches=newSeqOfCap[FieldBranch](0)
                      )
                    ],
                    conditionOfBranch=some nnkOfBranch.newTree()
                  )
                ]
              )
            ],
            conditionOfBranch=some nnkOfBranch.newTree()
          ),
          initFieldBranch(
            fields = @[
              initField(
                nameIdent=ident "Third",
                typeNode=bindSym "Test",
                features=initEmptyFieldFeatures(),
                public=false,
                isCase=false,
                branches=newSeqOfCap[FieldBranch](0)
              ),
              initField(
                nameIdent=ident "Nope",
                typeNode=bindSym "Test",
                features=initFieldFeatures(
                  skipSerializing=false,
                  skipDeserializing=false,
                  untagged=true,
                  renameSerialize=none NimNode,
                  renameDeserialize=none NimNode,
                  skipSerializeIf=none NimNode,
                  serializeWith=none NimNode,
                  deserializeWith=none NimNode,
                  defaultValue=none NimNode,
                  aliases = @[],
                  deserWith=none NimNode
                ),
                public=false,
                isCase=true,
                branches = @[
                  initFieldBranch(
                    fields = @[
                      initField(
                        nameIdent=ident "Fourth",
                        typeNode=bindSym "Test",
                        features=initEmptyFieldFeatures(),
                        public=false,
                        isCase=false,
                        branches=newSeqOfCap[FieldBranch](0)
                      )
                    ],
                    conditionOfBranch=some nnkOfBranch.newTree()
                  )
                ]
              )
            ],
            conditionOfBranch=some nnkOfBranch.newTree()
          )
        ]
      )
    ]
  
    var fieldNames = @[
      "Fourth",
      "Third",
      "Second",
      "First"
    ]

    for field in flatten fields:
      doAssert field.nameIdent.strVal == fieldNames.pop()

  block:
    let field = initField(
      nameIdent=ident "First",
      typeNode=bindSym "Test",
      features=initFieldFeatures(
        skipSerializing=false,
        skipDeserializing=false,
        untagged=false,
        renameSerialize=some newLit "Serialize",
        renameDeserialize=some newLit "Deserialize",
        skipSerializeIf=none NimNode,
        serializeWith=none NimNode,
        deserializeWith=none NimNode,
        defaultValue=none NimNode,
        aliases = @[],
        deserWith=none NimNode
      ),
      public=false,
      isCase=false,
      branches=newSeqOfCap[FieldBranch](0)
    )

    doAssert serializeName(field) == "Serialize"
    doAssert deserializeName(field) == @["Deserialize"]

  block:
    let checkTable = [
      (newLit "barFoo", "barFoo"),
      (ident "barFoo", "fooBar"),
      (bindSym "CamelCase", "fooBar"),
      (bindSym "CobolCase", "FOO-BAR"),
      (bindSym "KebabCase", "foo-bar"),
      (bindSym "PascalCase", "FooBar"),
      (bindSym "PathCase", "foo/bar"),
      (bindSym "SnakeCase", "foo_bar"),
      (bindSym "PlainCase", "foo bar"),
      (bindSym "TrainCase", "Foo-Bar"),
      (bindSym "UpperSnakeCase", "FOO_BAR"),
    ]
    for (renameValue, checkValue) in checkTable:
      let field = initField(
        nameIdent=ident "fooBar",
        typeNode=bindSym "Test",
        features=initFieldFeatures(
          skipSerializing=false,
          skipDeserializing=false,
          untagged=false,
          renameSerialize=some renameValue,
          renameDeserialize=some renameValue,
          skipSerializeIf=none NimNode,
          serializeWith=none NimNode,
          deserializeWith=none NimNode,
          defaultValue=none NimNode,
          aliases = @[],
          deserWith=none NimNode
        ),
        public=false,
        isCase=false,
        branches=newSeqOfCap[FieldBranch](0)
      )
      doAssert field.serializeName == checkValue
      doAssert field.deserializeName == @[checkValue]

    let aliasCheckTable = [
      (newLit "barFoo", @["barFoo", "fooBar"]),
      (ident "barFoo", @["fooBar"]),
      (bindSym "CamelCase", @["fooBar", "fooBar"]),
      (bindSym "CobolCase", @["FOO-BAR", "fooBar"]),
      (bindSym "KebabCase", @["foo-bar", "fooBar"]),
      (bindSym "PascalCase", @["FooBar", "fooBar"]),
      (bindSym "PathCase", @["foo/bar", "fooBar"]),
      (bindSym "SnakeCase", @["foo_bar", "fooBar"]),
      (bindSym "PlainCase", @["foo bar", "fooBar"]),
      (bindSym "TrainCase", @["Foo-Bar", "fooBar"]),
      (bindSym "UpperSnakeCase", @["FOO_BAR", "fooBar"]),
    ]

    for (renameValue, checkValue) in aliasCheckTable:
      let field = initField(
        nameIdent=ident "fooBar",
        typeNode=bindSym "Test",
        features=initFieldFeatures(
          skipSerializing=false,
          skipDeserializing=false,
          untagged=false,
          renameSerialize=none NimNode,
          renameDeserialize=none NimNode,
          skipSerializeIf=none NimNode,
          serializeWith=none NimNode,
          deserializeWith=none NimNode,
          defaultValue=none NimNode,
          aliases = @[renameValue],
          deserWith=none NimNode
        ),
        public=false,
        isCase=false,
        branches=newSeqOfCap[FieldBranch](0)
      )
      doAssert field.deserializeName == checkValue

run()