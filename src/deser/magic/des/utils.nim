import std/[
  macros,
  options,
  strutils
]

from ../../des/error import
  UnexpectedSigned,
  UnexpectedUnsigned,
  UnexpectedString,
  UnexpectedFloat,
  raiseInvalidValue


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
    type HackType[Value] = object
    type `visitorType` = HackType[`T`]
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


macro genArray(size: static[int], T: typedesc): array =
  # [get(nextElement[T](sequence)), ...]
  result = nnkBracket.newTree()

  for i in 0..size:
    result.add newCall(
      bindSym "get",
      newCall(
        nnkBracketExpr.newTree(
          ident "nextElement",
          T
        ),
        ident "sequence"
      )
    )


template visitEnumIntBody {.dirty.} =
  bind
    raiseInvalidValue,
    UnexpectedSigned,
    UnexpectedUnsigned

  if value.int64 in T.low.int64..T.high.int64:
    value.T
  else:
    when value is SomeSignedInt:
      raiseInvalidValue(UnexpectedSigned(value), self)
    else:
      raiseInvalidValue(UnexpectedUnsigned(value), self)


template visitRangeIntBody {.dirty.} =
  bind visitEnumIntBody
  
  visitEnumIntBody()


template visitRangeFloatBody {.dirty.} =
  bind raiseInvalidValue, UnexpectedFloat

  if value.float64 in T.low.float64..T.high.float64:
    value.T
  else:
    raiseInvalidValue(UnexpectedFloat(value.float64), self)


# https://github.com/GULPF/samson/blob/71ead61104302abfc0d4463c91f73a4126b2184c/src/samson/private/xtypetraits.nim#L29
macro rangeUnderlyingType(typ: typedesc[range]): typedesc =
  result = getType(getType(typ)[1][1])
{.pop.}
