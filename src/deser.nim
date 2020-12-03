import macros
import anycase_fork

type
  RenameKind* = enum
    rkNothing,
    rkCamelCase,
    rkSnakeCase,
    rkKebabCase,
    rkPascalCase,
    rkUpperSnakeCase,
    rkUpperKebabCase

# https://github.com/nim-lang/Nim/issues/16158
template rename*(ser = "", des = "") {.pragma.}
template renameAll*(ser: RenameKind = rkNothing, des: RenameKind = rkNothing) {.pragma.}
template skipSerializeIf*(condition: typed{`proc`}) {.pragma.}
template flat*() {.pragma.}
template skip*() {.pragma.}
template skipSerializing*() {.pragma.}
template skipDeserializing*() {.pragma.}
template deserializeWith*(convert: typed{`proc`}) {.pragma.}
template serializeWith*(convert: typed{`proc`}) {.pragma.}

# https://github.com/nim-lang/Nim/issues/16108
# hack to instantiate type
template hackType*[T](x: T): T =
  ## for internal use only
  x

template safeCondition*(x: untyped): bool =
  ## for internal use only
  #[
    `when v.hasCustomPragma(...) and v.getCustomPragmaVal(...) == ...`
    this code can sometimes throw a compilation error, 
    because getCustomPragmaVal can return nil. This occurs even though hasCustomPragma returned false.
    
    so you must write `when v.hasCustomPragma(...) and safeCondition(v.getCustomPragmaVal(...) == ...)`
  ]#
  when compiles(x):
    x
  else:
    false

macro getFirstArgumentType*(f: typed{`proc`}): typedesc =
  ## for internal use only
  f.getType[2]

macro getProcReturnType*(f: typed{`proc`}): typedesc =
  ## for internal use only
  f.getType[1]

template getPragmaOrNothing*(inOb: typedesc, pragm: typed): tuple[] | typed =
  ## for internal use only
  when inOb.hasCustomPragma(pragm):
    hackType(inOb.getCustomPragmaVal(pragm))
  else:
    ()

template forTuple*(value: untyped, x: static[tuple], actions: untyped) =
  ## for internal use only
  # special template for processing tuple that comes from parent objects for flat objects
  for field in fields(x):
    const value = field
    when field is tuple[]:
      discard
    elif field is tuple:
      forTuple(value, field, actions)
    else:
      actions

template forTupleVar*(value: untyped, x: tuple, actions: untyped) =
  ## for internal use only
  for field in fields(x):
    var value = field
    when field is tuple[]:
      discard
    elif field is tuple:
      forTuple(value, field, actions)
    else:
      actions

# hack to apply only the first serializeWith that fits the types
proc hackSerializeWith*(x: static[tuple], v: auto): auto {.inline.} =
  forTupleVar(tv, x):
    when compiles(hackType(tv(v))) and $result.type == "untyped":
      result = hackType(tv(v))

proc renamer*(x: string, rule: RenameKind): string {.compileTime.} =
  case rule
  of rkCamelCase:
      camel(x)
  of rkSnakeCase:
      snake(x)
  of rkKebabCase:
      kebab(x)
  of rkPascalCase:
      pascal(x)
  of rkUpperSnakeCase:
      upperSnake(x)
  of rkUpperKebabCase:
      cobol(x)
  else:
      x

template actualForSerFields*(key: untyped, value: untyped, inOb: object | tuple, actions: untyped, flatSkip: static[tuple], flatRenameAll: static[tuple | tuple[ser: RenameKind, des: RenameKind]], flatSerWith: static[tuple]) =
  ## for internal use only
  for k, v in fieldPairs(inOb):
    when not(v.hasCustomPragma(skip) or v.hasCustomPragma(skipSerializing)):
      var isSkip = false

      #[
        Skip logic
        Where can the conditions come from:
          - object
          - parrent object if current is `flat`
          - field
        If one of the conditions returns true the field will be skipped
      ]#

      # apply "global" skipSerializeIf from object to current field
      # will be silently skipped if the types don't match
      when type(inOb).hasCustomPragma(skipSerializeIf) and compiles(hackType(type(inOb).getCustomPragmaVal(skipSerializeIf)(v))):
        isSkip = hackType(type(inOb).getCustomPragmaVal(skipSerializeIf)(v))

      # apply skipSerializeIf from parent object to `flat` child's field
      # will be silently skipped if the types don't match
      when flatSkip is not tuple[]:
        forTuple(tv {.used.}, flatSkip):
          when compiles(hackType(tv(v))):
            if not isSkip:
              isSkip = hackType(tv(v))

      # apply `skipSerializeIf` from current field
      # instead of a silent skip, a compile-time error will be called if the types do not match
      when v.hasCustomPragma(skipSerializeIf):
        if not isSkip:
          isSkip = hackType(v.getCustomPragmaVal(skipSerializeIf)(v))

      if not isSkip:
        # `flat` logic
        # recursively calling actualForSerFields
        when v is object | tuple and v.hasCustomPragma(flat):
          # `skipSerializeIf` and `renameAll` are tuples itself
          # so need to get only value that require for serialize
          const checkedFlatSkip = static:
            const temp = getPragmaOrNothing(type(inOb), skipSerializeIf)
            when temp isnot tuple[] and temp is tuple:
              temp[0]
            else:
              temp
          const checkedFlatRenameAll = static:
            const temp = getPragmaOrNothing(type(inOb), renameAll)
            when temp isnot tuple[] and temp is tuple:
              temp[0]
            else:
              temp
          actualForSerFields(
            key,
            value,
            v,
            actions,
            (checkedFlatSkip, flatSkip),  # apply skipSerializeIf to flat
            (checkedFlatRenameAll, flatRenameAll),  # apply renameAll to flat
            (getPragmaOrNothing(type(inOb), serializeWith), flatSerWith)  # apply serializeWith to flat
          )
        else:
          # `rename` logic
          # `rename` from field has a higher priority
          when v.hasCustomPragma(rename) and v.getCustomPragmaVal(rename)[0].len > 0:
            const key = v.getCustomPragmaVal(rename)[0]
          elif type(inOb).hasCustomPragma(renameAll) and safeCondition(type(inOb).getCustomPragmaVal(renameAll)[0] != rkNothing):
              const key = static(renamer(k, type(inOb).getCustomPragmaVal(renameAll)[0]))
          elif flatRenameAll isnot tuple[]:
            # in the first place is `renameAll` from the last parent object, that is, the highest priority
            const key = static:
              var key = k
              forTuple(tv {.used.}, flatRenameAll):
                key = static(renamer(k, tv))
                break
              key
          else:
            const key = k

          # if a suitable `renameAll` was not found
          when not declaredInScope(key):
            const key = k

          # `serializeWith` logic
          # `serializeWith` from field has a higher priority
          when v.hasCustomPragma(serializeWith):
            # instead of a silent skip, a compile-time error will be called if the types do not match
            let value = hackType(v.getCustomPragmaVal(serializeWith)(v))
          elif type(inOb).hasCustomPragma(serializeWith) and compiles(type(inOb).getCustomPragmaVal(serializeWith)(v)):
            # will be silently skipped if the types don't match
            let value = hackType(type(inOb).getCustomPragmaVal(serializeWith)(v))
          elif flatSerWith isnot tuple[]:
            # will be silently skipped if the types don't match
            when compiles(hackSerializeWith(flatSerWith, v).type):
              let value = hackSerializeWith(flatSerWith, v)
            else:
              let value = v
          else:
            let value = v

          # if a suitable `serializeWith` was not found
          when not declaredInScope(value):
            let value = v

          actions

template actualForDesFields*(key: untyped, value: untyped, inOb: var object | var tuple, actions: untyped) =
  for k, v in fieldPairs(inOb):
    when not(v.hasCustomPragma(skip) or v.hasCustomPragma(skipDeserializing)):
      # init ref object
      when v is ref:
        if v == nil:
          new(v)

      # `flat` logic
      # recursively calling actualForDesFields
      when v is object | tuple and v.hasCustomPragma(flat):
        actualForDesFields(key, value, v, actions)
      else:
        #[
          `rename` logic
          `rename` from field has a higher priority

          Behavior of `rename` during deserialization differs from that during serialization. 
          Since you most often need to rename a field immediately for both serialization and deserialization, you just need to specify `rename` only for serialization. 
          This has a downside : if you don't need to change the field during deserialization, you will have to specify it explicitly.
        ]#
        when v.hasCustomPragma(rename):
          when v.getCustomPragmaVal(rename)[0].len > 0:
            var key = v.getCustomPragmaVal(rename)[0]
          elif v.getCustomPragmaVal(rename)[1].len > 0:
            var key = v.getCustomPragmaVal(rename)[1]
        elif type(inOb).hasCustomPragma(renameAll):
          when type(inOb).getCustomPragmaVal(renameAll)[0].len > 0:
            var key = static(renamer(k, type(inOb).getCustomPragmaVal(renameAll)[0]))
          elif type(inOb).getCustomPragmaVal(renameAll)[1].len > 0:
            var key = static(renamer(k, type(inOb).getCustomPragmaVal(renameAll)[1]))
        else:
          var key = k

        #[
          `deserializeWith` logic is executed in two steps:
          1. Initialization of the variable that is given to the Deserializer, with the type that is expected in json
          2. Convert this variable using `deserializeWith` to the object field type
        ]#

        # step one
        when v.hasCustomPragma(deserializeWith):
          var value: getFirstArgumentType(hackType(v.getCustomPragmaVal(deserializeWith)))
        # if `deserializeWith` from object
        # check that type of `deserializeWith` result equal to field type
        elif type(inOb).hasCustomPragma(deserializeWith) and v is getProcReturnType(hackType(type(inOb).getCustomPragmaVal(deserializeWith))):
          var value: getFirstArgumentType(hackType(type(inOb).getCustomPragmaVal(deserializeWith)))
        else:
          var value: type(v)

        actions

        # step two
        # `deserializeWith` from field has a higher priority
        when v.hasCustomPragma(deserializeWith):
          # instead of a silent skip, a compile-time error will be called if the types do not match
          v = hackType(v.getCustomPragmaVal(deserializeWith)(value))
        elif type(inOb).hasCustomPragma(deserializeWith) and v is getProcReturnType(hackType(type(inOb).getCustomPragmaVal(deserializeWith))):
          v = hackType(type(inOb).getCustomPragmaVal(deserializeWith)(value))
        else:
          v = value

template forSerFields*(key: untyped, value: untyped, inOb: object | tuple, actions: untyped) =
  actualForSerFields(`key`, `value`, `inOb`, `actions`, (), (), ())

template forDesFields*(key: untyped, value: untyped, inOb: var object | var tuple, actions: untyped) =
  actualForDesFields(`key`, `value`, `inOb`, `actions`)
