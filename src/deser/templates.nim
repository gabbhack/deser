import utils

template actualForSerFields*(key: untyped, value: untyped, inOb: object | tuple | ref, actions: untyped, flatSkipSerIf: proc | tuple[] = (), flatRenameAll: RenameKind | tuple[] = (), flatSerWith: proc | tuple[] = ()) =
  ## for internal use only
  for k, v in fieldPairs(checkedObj(inOb)):
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

      when type(inOb).hasCustomPragma(skipSerializeIf) and compiles(hackType(getCustomPragmaVal(type(inOb), skipSerializeIf)(v))):
        isSkip = hackType(getCustomPragmaVal(type(inOb), skipSerializeIf)(v))

      # apply skipSerializeIf from parent object to `flat` child's field
      # will be silently skipped if the types don't match
      when flatSkipSerIf isnot tuple[]:
        when compiles(hackType(flatSkipSerIf(v))):
          if not isSkip:
            isSkip = hackType(flatSkipSerIf(v))

      # apply `skipSerializeIf` from current field
      # instead of a silent skip, a compile-time error will be called if the types do not match
      when v.hasCustomPragma(skipSerializeIf):
        if not isSkip:
          isSkip = hackType(getCustomPragmaVal(v, skipSerializeIf)(v))

      if not isSkip:
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
            checkedFlatSkip(),  # apply skipSerializeIf to flat
            checkedFlatRenameAll(),  # apply renameAll to flat
            checkedFlatSerWith() # apply serializeWith to flat
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
            const key = static(renamer(k, flatRenameAll))
          else:
            const key = k

          # `serializeWith` logic
          # `serializeWith` from field has a higher priority
          when v.hasCustomPragma(serializeWith):
            # instead of a silent skip, a compile-time error will be called if the types do not match
            let value = hackType(v.getCustomPragmaVal(serializeWith)(v))
          elif type(inOb).hasCustomPragma(serializeWith) and compiles(hackType(getCustomPragmaVal(type(inOb), serializeWith)(v))):
            # will be silently skipped if the types don't match
            let value = hackType(getCustomPragmaVal(type(inOb), serializeWith)(v))
          elif flatSerWith isnot tuple[]:
            # will be silently skipped if the types don't match
            when compiles(hackType(flatSerWith(v))):
              let value = hackType(flatSerWith(v))
            else:
              let value = v
          else:
            let value = v

          actions

template actualForDesFields*(key: untyped, value: untyped, inOb: var object | var tuple | ref, actions: untyped, flatRenameAll: RenameKind | tuple[] = (), flatDesWith: proc | tuple[] = ()) =
  ## for internal use only
  when inOb is ref:
    if inOb == nil:
      new inOb
  for k, v in fieldPairs(checkedObj(inOb)):
    when not(v.hasCustomPragma(skip) or v.hasCustomPragma(skipDeserializing)):
      when v is ref:
        if v == nil:
          new v
      # `flat` logic
      # recursively calling actualForDesFields
      when v is var object | var tuple | ref and v.hasCustomPragma(flat):
        # `renameAll` and `serializeWith` are tuples itself
        # so need to get only value that require for serialize
        template checkedFlatRenameAll: untyped =
          when hasCustomPragma(type(inOb), renameAll):
            when getCustomPragmaVal(type(inOb), renameAll)[0] == rkNothing and getCustomPragmaVal(type(inOb), renameAll)[1] != rkNothing:
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
          checkedFlatRenameAll(),  # apply renameAll to flat
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
            const key = static(renamer(k, type(inOb).getCustomPragmaVal(renameAll)[0]))
          elif type(inOb).getCustomPragmaVal(renameAll)[1] != rkNothing:
            const key = static(renamer(k, type(inOb).getCustomPragmaVal(renameAll)[1]))
          else:
            const key = k
        elif flatRenameAll isnot tuple[]:
            # in the first place is `renameAll` from the last parent object, that is, the highest priority
            const key = static(renamer(k, flatRenameAll))
        else:
          const key = k

        #[
          `deserializeWith` logic is executed in two steps:
          1. Initialization of the variable that is given to the Deserializer, with the type that is expected in json
          2. Convert this variable using `deserializeWith` to the object field type
        ]#
        # step one

        when v.hasCustomPragma(deserializeWith):
          var value: getFirstArgumentType(v.getCustomPragmaVal(deserializeWith))
        # if `deserializeWith` from object
        # check that type of `deserializeWith` result equal to field type
        elif type(inOb).hasCustomPragma(deserializeWith) and safeCondition(v is getProcReturnType(getCustomPragmaVal(type(inOb), deserializeWith))):
          var value: getFirstArgumentType(getCustomPragmaVal(type(inOb), deserializeWith))
        elif flatDesWith isnot tuple[] and safeCondition(v is getProcReturnType(flatDesWith)):
          var value: getFirstArgumentType(flatDesWith)
        else:
          var value: type(v)

        actions

        # step two
        # `deserializeWith` from field has a higher priority
        when v.hasCustomPragma(deserializeWith):
          # instead of a silent skip, a compile-time error will be called if the types do not match
          v = hackType(v.getCustomPragmaVal(deserializeWith)(value))
        elif type(inOb).hasCustomPragma(deserializeWith) and safeCondition(v is getProcReturnType(getCustomPragmaVal(type(inOb), deserializeWith))):
          v = hackType(getCustomPragmaVal(type(inOb), deserializeWith)(value))
        elif flatDesWith isnot tuple[] and safeCondition(v is getProcReturnType(flatDesWith)):
          v = hackType(flatDesWith(value))
        else:
          v = move(value)