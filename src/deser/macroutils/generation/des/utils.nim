import std/[
  macros,
  options
]

from std/strutils import
  capitalizeAscii

from deser/des/helpers import
  implVisitor

from deser/des/errors import
  initUnexpectedSigned,
  initUnexpectedUnsigned,
  initUnexpectedString,
  initUnexpectedFloat,
  raiseInvalidValue,
  raiseMissingField


func defImplVisitor*(selfType: NimNode, public: bool): NimNode =
  # implVisitor(selfType, returnType)
  let
    implVisitorSym = bindSym "implVisitor"
    public = newLit public

  quote do:
    `implVisitorSym`(`selfType`, public=`public`)

func defExpectingProc*(selfType, body: NimNode): NimNode =
  let
    expectingIdent = ident "expecting"
    selfIdent = ident "self"

  quote do:
    proc `expectingIdent`(`selfIdent`: `selfType`): string =
      `body`

macro toByteArray*(str: static[string]): array =
  result = nnkBracket.newTree()
  
  for s in str:
    result.add newLit s.byte

template getOrDefault*[T](field: Option[T]): T =
  bind
    isSome,
    unsafeGet

  if isSome(field):
    unsafeGet(field)
  else:
    # HACK: https://github.com/nim-lang/Nim/issues/20033
    default(typedesc[T])

template getOrDefaultValue*[T](field: Option[T], defaultValue: T): T =
  bind
    isSome,
    unsafeGet

  if isSome(field):
    unsafeGet(field)
  else:
    defaultValue

template getOrRaise*[T](field: Option[T], name: static[string]): T =
  bind
    Option,
    isSome,
    unsafeGet,
    none,
    raiseMissingField

  if isSome(field):
    unsafeGet(field)
  else:
    when T is Option:
      # HACK: https://github.com/nim-lang/Nim/issues/20033
      default(typedesc[T])
    else:
      raiseMissingField(name)

template getOrBreak*[T](field: Option[T]): T =
  bind
    Option,
    isSome,
    unsafeGet,
    none

  if isSome(field):
    unsafeGet(field)
  else:
    when T is Option:
      # HACK: https://github.com/nim-lang/Nim/issues/20033
      default(typedesc[T])
    else:
      break

macro genPrimitive*(typ: typed{`type`}, deserializeMethod: untyped = nil, floats: static[bool] = false) =
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
        ident "deserialize" & typ.strVal.capitalizeAscii
    )
    typeStringLit = typ.toStrLit
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
              raiseInvalidValue(initUnexpectedSigned(value.int64), self)
          elif value is SomeUnsignedInt:
            if not (value.uint64 <= self.Value.high.uint64):
              raiseInvalidValue(initUnexpectedUnsigned(value.uint64), self)
          else:
            {.error: "Unknown type `" & $self.Value & "`, expected int or uint".}
        elif self.Value is SomeSignedInt:
          when value is SomeSignedInt:
            if not (self.Value.low.int64 <= value.int64 and value.int64 <= self.Value.high.int64):
              raiseInvalidValue(initUnexpectedSigned(value.int64), self)
          elif value is SomeUnsignedInt:
            if not (value.uint64 <= self.Value.high.uint64):
                raiseInvalidValue(initUnexpectedUnsigned(value.uint64), self)
          else:
            {.error: "Unknown type `" & $self.Value() & "`, expected int or uint".}

        self.Value(value)
  
  result.add quote do:
    type HackType[Value] = object
    type `visitorType` = HackType[`typ`]
    implVisitor(`visitorType`, true)

    proc expecting*(`selfIdent`: `visitorType`): string = `typeStringLit`

    proc deserialize*(`selfIdent`: typedesc[`typ`], `deserializerIdent`: var auto): `typ` =
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


macro genArray*(size: static[int], T: typedesc): array =
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


template visitEnumIntBody* {.dirty.} =
  bind
    raiseInvalidValue,
    initUnexpectedSigned,
    initUnexpectedUnsigned

  if value.int64 in T.low.int64..T.high.int64:
    value.T
  else:
    when value is SomeSignedInt:
      raiseInvalidValue(initUnexpectedSigned(value), self)
    else:
      raiseInvalidValue(initUnexpectedUnsigned(value), self)


template visitRangeIntBody* {.dirty.} =
  bind visitEnumIntBody
  
  visitEnumIntBody()


template visitRangeFloatBody* {.dirty.} =
  bind
    raiseInvalidValue,
    initUnexpectedFloat

  if value.float64 in T.low.float64..T.high.float64:
    value.T
  else:
    raiseInvalidValue(initUnexpectedFloat(value.float64), self)


# https://github.com/GULPF/samson/blob/71ead61104302abfc0d4463c91f73a4126b2184c/src/samson/private/xtypetraits.nim#L29
macro rangeUnderlyingType*(typ: typedesc[range]): typedesc =
  result = getType(getType(typ)[1][1])
