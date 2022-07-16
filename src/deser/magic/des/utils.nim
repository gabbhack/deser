import std/[
  macros,
  options,
  strutils
]

from ../../des/helpers import
  Visitor
from ../../des/error import
  UnexpectedSigned,
  UnexpectedUnsigned,
  UnexpectedString,
  raiseInvalidValue


from ../../pragmas import lowerCased


{.push used.}
macro toByteArray(str: static[string]): array =
  result = nnkBracket.newTree()
  
  for s in str:
    result.add s.byte.newLit


template getOrDefault[T](field: Option[T], defaultValue: T): T =
  bind isSome, unsafeGet

  if isSome(field):
    unsafeGet(field)
  else:
    defaultValue


template getOrRaise[T](field: Option[T], name: static[string]): T =
  bind isSome, unsafeGet, Option, none

  if isSome(field):
    unsafeGet(field)
  else:
    when T is Option:
      # HACK: https://github.com/nim-lang/Nim/issues/20033
      default(typedesc[T])
    else:
      raiseMissingField(name)


template getOrBreak[T](field: Option[T]): T =
  bind isSome, unsafeGet, Option, none

  if isSome(field):
    unsafeGet(field)
  else:
    when T is Option:
      # HACK: https://github.com/nim-lang/Nim/issues/20033
      default(typedesc[T])
    else:
      break


macro genPrimitive(T: typed{`type`}, deserializeMethod: untyped = nil, floats: static[bool] = false) =
  result = newStmtList()
  var
    visitorSym = bindSym "Visitor"
    selfIdent = ident "self"
    valueIdent = ident "value"
    deserializerIdent = ident "deserializer"
    visitorType = genSym(nskType, "Visitor")
    deserializeMethodIdent = (
      if deserializeMethod.kind != nnkNilLit:
        deserializeMethod
      else:
        ident "deserialize" & T.strVal.capitalizeAscii
    )
    typeStringLit = T.toStrLit
    procs = @[
      (ident "visitInt8", ident "int8"),
      (ident "visitInt16", ident "int16"),
      (ident "visitInt32", ident "int32"),
      (ident "visitInt64", ident "int64"),
      (ident "visitUint8", ident "uint8"),
      (ident "visitUint16", ident "uint16"),
      (ident "visitUint32", ident "uint32"),
      (ident "visitUint64", ident "uint64"),
    ]

    body = quote do:
      when type(value) is self.Value:
        value
      else:
        when self.Value is SomeUnsignedInt:
          when value is SomeSignedInt:
            if not (0 <= value and value.uint64 <= self.Value.high.uint64):
              raiseInvalidValue(UnexpectedSigned(value.int64), self)
          elif value is SomeUnsignedInt:
            if not (value.uint64 <= self.Value.high.uint64):
              raiseInvalidValue(UnexpectedUnsigned(value.uint64), self)
          else:
            {.error: "Unknown type `" & $self.Value & "`, expected int or uint".}
        elif self.Value is SomeSignedInt:
          when value is SomeSignedInt:
            if not (self.Value.low.int64 <= value.int64 and value.int64 <= self.Value.high.int64):
              raiseInvalidValue(UnexpectedSigned(value.int64), self)
          elif value is SomeUnsignedInt:
            if not (value.uint64 <= self.Value.high.uint64):
                raiseInvalidValue(UnexpectedUnsigned(value.uint64), self)
          else:
            {.error: "Unknown type `" & $self.Value() & "`, expected int or uint".}

        self.Value(value)
  
  result.add quote do:
    type `visitorType` = `visitorSym`[`T`]
    implVisitor(`visitorType`, true)

    proc expecting*(`selfIdent`: `visitorType`): string = `typeStringLit`

    proc deserialize*(`selfIdent`: typedesc[`T`], `deserializerIdent`: var auto): `T` =
      mixin `deserializeMethodIdent`

      deserializer.`deserializeMethodIdent`(`visitorType`())
  
  if floats:
    procs.add @[
      (ident "visitFloat32", ident "float32"),
      (ident "visitFloat64", ident "float64")
    ]

  for (procIdent, valueType) in procs:
    result.add quote do:
      proc `procIdent`*(`selfIdent`: `visitorType`, `valueIdent`: `valueType`): self.Value =
        `body`


macro genEnumCase(typ: typedesc[enum]): enum =
  let
    # some magic numbers
    typ = typ[1][0][0][1][2][0]
    typeDef = typ.getImpl
    enumTy = typeDef[2]
    lowerCasedSym = bindSym "lowerCased"
    lowerCased = (
      var temp = false
      if typeDef[0].kind == nnkPragmaExpr:
        for i in typeDef[0]:
          if i.kind == nnkPragma and i[0] == lowerCasedSym:
            temp = true
            break
      temp
    )

  result = nnkCaseStmt.newTree(ident "value")

  for variant in enumTy[1..enumTy.len-1]:
    let str = (
      if lowerCased:
        variant.strVal.toLowerAscii
      else:
        variant.strVal
    )
    result.add nnkOfBranch.newTree(
      newLit str,
      newStmtList(
        newDotExpr(
          typ,
          variant
        )
      )
    )
  
  result.add nnkElse.newTree(
    newCall(
      bindSym "raiseInvalidValue",
      newCall(
        bindSym "UnexpectedString",
        ident "value"
      ),
      ident "self"
    )
  )


macro genArray(size: static[int], T: typedesc): array =
  # [get(nextElement[T](sequence)), ...]
  result = nnkBracket.newTree()

  for i in 0..(size-1):
    result.add newCall(
      bindSym "get",
      newCall(
        nnkBracketExpr.newTree(
          ident "nextElement",
          ident "T"
        ),
        ident "sequence"
      )
    )


template visitEnumIntBody {.dirty.} =
  bind raiseInvalidValue
  bind UnexpectedSigned
  bind UnexpectedUnsigned

  if value.int64 in T.low.int64..T.high.int64:
    T(value)
  else:
    when value is SomeSignedInt:
      raiseInvalidValue(UnexpectedSigned(value), self)
    else:
      raiseInvalidValue(UnexpectedUnsigned(value), self)
{.pop.}
