import utils, hacks, pragmas

template actualForSerFields*(key: untyped, value: untyped, inOb: object |
    tuple | ref, actions: untyped, flatSkipSerIf: proc | tuple[] = (),
    flatRenameAll: RenameKind = rkNothing, flatSerWith: proc | tuple[] = ()) =
  ## for internal use only
  for k, v in fieldPairs(checkedObj(inOb)):
    when not(v.hasCustomPragma(skip) or v.hasCustomPragma(skipSerializing)):
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

      when type(inOb).hasCustomPragma(skipSerializeIf) and compiles(hackType(
          getCustomPragmaVal(type(inOb), skipSerializeIf)(v))):
        var isSkip = hackType(getCustomPragmaVal(type(inOb), skipSerializeIf)(v))

      # apply skipSerializeIf from parent object to `flat` child's field
      # will be silently skipped if the types don't match
      when flatSkipSerIf isnot tuple[] and compiles(hackType(flatSkipSerIf(v))):
        when declared(isSkip):
          isSkip = isSkip or hackType(flatSkipSerIf(v))
        else:
          var isSkip = hackType(flatSkipSerIf(v))

      # apply `skipSerializeIf` from current field
      # instead of a silent skip, a compile-time error will be called if the types do not match
      when v.hasCustomPragma(skipSerializeIf):
        when declared(isSkip):
          isSkip = isSkip or hackType(getCustomPragmaVal(v, skipSerializeIf)(v))
        else:
          var isSkip = hackType(getCustomPragmaVal(v, skipSerializeIf)(v))

      template body: untyped {.dirty.} =
        # `flat` logic
        # recursively calling actualForSerFields
        when v is object | tuple | ref and v.hasCustomPragma(flat):
          # `skipSerializeIf`, `renameAll` and `serializeWith` are tuples itself
          # so need to get only value that require for serialize
          template checkedFlatSkip: untyped =
            when hasCustomPragma(type(inOb), skipSerializeIf):
              getCustomPragmaVal(type(inOb), skipSerializeIf)
            else:
              flatSkipSerIf
          template checkedFlatRenameAll: untyped =
            when hasCustomPragma(type(inOb), renameAll):
              getCustomPragmaVal(type(inOb), renameAll)[0]
            else:
              flatRenameAll
          template checkedFlatSerWith: untyped =
            when hasCustomPragma(type(inOb), serializeWith):
              getCustomPragmaVal(type(inOb), serializeWith)
            else:
              flatSerWith
          actualForSerFields(
            key,
            value,
            v,
            actions,
            checkedFlatSkip(), # apply skipSerializeIf to flat
            checkedFlatRenameAll(), # apply renameAll to flat
            checkedFlatSerWith() # apply serializeWith to flat
          )
        else:
          # `rename` logic
          # `rename` from field has a higher priority
          when v.hasCustomPragma(rename) and v.getCustomPragmaVal(rename)[
              0].len > 0:
            const key = v.getCustomPragmaVal(rename)[0]
          elif type(inOb).hasCustomPragma(renameAll) and safeCondition(type(
              inOb).getCustomPragmaVal(renameAll)[0] != rkNothing):
            const key = static(renamer(k, type(inOb).getCustomPragmaVal(
                renameAll)[0]))
          elif flatRenameAll != rkNothing:
            # in the first place is `renameAll` from the last parent object, that is, the highest priority
            const key = static(renamer(k, flatRenameAll))
          else:
            const key = k

          # `serializeWith` logic
          # `serializeWith` from field has a higher priority
          when v.hasCustomPragma(serializeWith):
            # instead of a silent skip, a compile-time error will be called if the types do not match
            template value: untyped = hackType(v.getCustomPragmaVal(
                serializeWith)(v))
          elif type(inOb).hasCustomPragma(serializeWith) and compiles(hackType(
              getCustomPragmaVal(type(inOb), serializeWith)(v))):
            # will be silently skipped if the types don't match
            template value: untyped = hackType(getCustomPragmaVal(type(inOb),
                serializeWith)(v))
          elif flatSerWith isnot tuple[]:
            # will be silently skipped if the types don't match
            when compiles(hackType(flatSerWith(v))):
              template value: untyped = hackType(flatSerWith(v))
            else:
              template value: untyped = v
          else:
            template value: untyped = v
          actions

      # avoid generating an extra `isSkip` check
      when declared(isSkip):
        if not isSkip:
          body()
      else:
        body()

template actualForDesFields*(key: untyped, value: untyped, inOb: var object |
    var tuple | ref, actions: untyped, flatRenameAll: RenameKind = rkNothing,
    flatDesWith: proc | tuple[] = ()) =
  ## for internal use only
  for k, v in fieldPairs(checkedObj(inOb)):
    when not(v.hasCustomPragma(skip) or v.hasCustomPragma(skipDeserializing)):
      # `flat` logic
      # recursively calling actualForDesFields
      when v is var object | var tuple | ref and v.hasCustomPragma(flat):
        # `renameAll` and `serializeWith` are tuples itself
        # so need to get only value that require for serialize
        template checkedFlatRenameAll: untyped =
          when hasCustomPragma(type(inOb), renameAll):
            when getCustomPragmaVal(type(inOb), renameAll)[0] == rkNothing and
                getCustomPragmaVal(type(inOb), renameAll)[1] != rkNothing:
              getCustomPragmaVal(type(inOb), renameAll)[1]
            else:
              getCustomPragmaVal(type(inOb), renameAll)[0]
          else:
            flatRenameAll
        template checkedFlatDesWith: untyped =
          when hasCustomPragma(type(inOb), deserializeWith):
            getCustomPragmaVal(type(inOb), deserializeWith)
          else:
            flatDesWith
        actualForDesFields(
          key,
          value,
          v,
          actions,
          checkedFlatRenameAll(), # apply renameAll to flat
          checkedFlatDesWith() # apply serializeWith to flat
        )
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
            const key = v.getCustomPragmaVal(rename)[0]
          elif v.getCustomPragmaVal(rename)[1].len > 0:
            const key = v.getCustomPragmaVal(rename)[1]
          else:
            const key = k
        elif type(inOb).hasCustomPragma(renameAll):
          when type(inOb).getCustomPragmaVal(renameAll)[0] != rkNothing:
            const key = static(renamer(k, type(inOb).getCustomPragmaVal(
                renameAll)[0]))
          elif type(inOb).getCustomPragmaVal(renameAll)[1] != rkNothing:
            const key = static(renamer(k, type(inOb).getCustomPragmaVal(
                renameAll)[1]))
          else:
            const key = k
        elif flatRenameAll != rkNothing:
          # in the first place is `renameAll` from the last parent object, that is, the highest priority
          const key = static(renamer(k, flatRenameAll))
        else:
          const key = k

        #[
          `deserializeWith` logic is executed in two steps:
          1. Initialization of the variable that is given to the Deserializer, with the type that is expected in json
          2. Convert this variable using `deserializeWith` to the object field type
        ]#

        when v.hasCustomPragma(deserializeWith):
          var value {.noInit.}: getFirstArgumentType(v.getCustomPragmaVal(deserializeWith))
          # inside "actions" can contain a "break", which will interrupt the execution of the loop and the assignment will not happen.
          tryFinally(actions):
            v = hackType(v.getCustomPragmaVal(deserializeWith)(value))
        # if `deserializeWith` from object
        # check that type of `deserializeWith` result equal to field type
        elif type(inOb).hasCustomPragma(deserializeWith) and safeCondition(
            v is getProcReturnType(getCustomPragmaVal(type(inOb),
            deserializeWith))):
          var value {.noInit.}: getFirstArgumentType(getCustomPragmaVal(type(
              inOb), deserializeWith))
          tryFinally(actions):
            v = hackType(getCustomPragmaVal(type(inOb), deserializeWith)(value))
        elif flatDesWith isnot tuple[] and safeCondition(v is getProcReturnType(flatDesWith)):
          var value {.noInit.}: getFirstArgumentType(flatDesWith)
          tryFinally(actions):
            v = hackType(flatDesWith(value))
        else:
          template value: untyped = v
          # don't generate "try-finally" in the simple case for performance.
          actions
