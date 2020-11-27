import macros
import anycase_fork

type Nothing = object

# https://github.com/nim-lang/Nim/issues/16158
template rename*(ser = "", des = "") {.pragma.}
template renameAll*(ser = "", des = "") {.pragma.}
template skipSerializeIf*(condition: typed{`proc`}) {.pragma.}
template flat*() {.pragma.}
template skip*() {.pragma.}
template skipSerializing*() {.pragma.}
template skipDeserializing*() {.pragma.}
template fromType*(convert: typed{`proc`}) {.pragma.}
template intoType*(convert: typed{`proc`}) {.pragma.}

# https://github.com/nim-lang/Nim/issues/16108
# hack to instantiate type
template hack[T](x: T): T = x

macro getFirstArgumentType(f: typed{`proc`}): typedesc =
  f.getType[2]

macro getProcReturnType(f: typed{`proc`}): typedesc =
  f.getType[1]

proc renamer(x: string, rule: string): string {.compileTime.} =
  case rule
  of "camelCase":
      camel(x)
  of "snake_case":
      snake(x)
  of "kebab-case":
      kebab(x)
  of "PascalCase":
      pascal(x)
  of "UPPER_SNAKE_CASE":
      upperSnake(x)
  of "UPPER-KEBAB-CASE":
      cobol(x)
  else:
      x

template actualForSerFields*(key: untyped, value: untyped, inOb: object | tuple, actions: untyped, flatSkip: typed = Nothing()) =
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
      when type(inOb).hasCustomPragma(skipSerializeIf) and compiles(hack(type(inOb).getCustomPragmaVal(skipSerializeIf)(v))):
        isSkip = hack(type(inOb).getCustomPragmaVal(skipSerializeIf)(v))

      # apply skipSerializeIf from parent object to `flat` child's field
      # will be silently skipped if the types don't match
      when flatSkip is not Nothing and compiles(hack(flatSkip(v))):
        if not isSkip:
          isSkip = hack(flatSkip(v))

      # apply skipSerializeIf from current field
      # instead of a silent skip, a compile-time error will be called if the types do not match
      when v.hasCustomPragma(skipSerializeIf):
        if not isSkip:
          isSkip = hack(v.getCustomPragmaVal(skipSerializeIf)(v))

      if not isSkip:
        # `flat` logic
        # recursively calling actualForSerFields

        when v is object | tuple and v.hasCustomPragma(flat):
          when type(inOb).hasCustomPragma(skipSerializeIf):
            # parrent object has skipSerializeIf, so call actualForSerFields with flatSkip condition
            actualForSerFields(key, value, v, actions, type(inOb).getCustomPragmaVal(skipSerializeIf))
          else:
            actualForSerFields(key, value, v, actions)
        else:
          # `rename` logic
          # `rename` from field has a higher priority
          when v.hasCustomPragma(rename) and v.getCustomPragmaVal(rename)[0].len > 0:
            var key = v.getCustomPragmaVal(rename)[0]
          elif type(inOb).hasCustomPragma(renameAll) and type(inOb).getCustomPragmaVal(renameAll)[0].len > 0:
            var key = static(renamer(k, type(inOb).getCustomPragmaVal(renameAll)[0]))
          else:
            var key = k

          # `intoType` logic
          # `intoType` from field has a higher priority
          when v.hasCustomPragma(intoType):
            # instead of a silent skip, a compile-time error will be called if the types do not match
            var value = hack(v.getCustomPragmaVal(intoType)(v))
          elif type(inOb).hasCustomPragma(intoType) and compiles(type(inOb).getCustomPragmaVal(intoType)(v)):
            # will be silently skipped if the types don't match
            var value = hack(type(inOb).getCustomPragmaVal(intoType)(v))
          else:
            var value = v
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
          `fromType` logic is executed in two steps:
          1. Initialization of the variable that is given to the Deserializer, with the type that is expected in json
          2. Convert this variable using `fromType` to the object field type
        ]#

        # step one
        when v.hasCustomPragma(fromType):
          var value: getFirstArgumentType(hack(v.getCustomPragmaVal(fromType)))
        # if `fromType` from object
        # check that type of `fromType` result equal to field type
        elif type(inOb).hasCustomPragma(fromType) and v is getProcReturnType(hack(type(inOb).getCustomPragmaVal(fromType))):
          var value: getFirstArgumentType(hack(type(inOb).getCustomPragmaVal(fromType)))
        else:
          var value: type(v)

        actions

        # step two
        # `fromType` from field has a higher priority
        when v.hasCustomPragma(fromType):
          # instead of a silent skip, a compile-time error will be called if the types do not match
          v = hack(v.getCustomPragmaVal(fromType)(value))
        elif type(inOb).hasCustomPragma(fromType) and v is getProcReturnType(hack(type(inOb).getCustomPragmaVal(fromType))):
          v = hack(type(inOb).getCustomPragmaVal(fromType)(value))
        else:
          v = value

template forSerFields*(key: untyped, value: untyped, inOb: object | tuple, actions: untyped) =
  actualForSerFields(`key`, `value`, `inOb`, `actions`)

template forDesFields*(key: untyped, value: untyped, inOb: var object | var tuple, actions: untyped) =
  actualForDesFields(`key`, `value`, `inOb`, `actions`)
