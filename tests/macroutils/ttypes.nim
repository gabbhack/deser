discard """
  action: "compile"
"""
import std/[macros, options]

import deser/macroutils/types
import deser/pragmas


type Test = object

macro run =
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