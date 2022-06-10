import std/[macros]

import ../macroutils {.all.}


type
  EnumField = object
    enumFieldIdent: NimNode
    structFieldIdent: NimNode


proc genEnumField(field: Field): EnumField =
  result = EnumField(
    enumFieldIdent: genSym(nskEnumField, field.name.strVal),
    structFieldIdent: field.name
  )


proc genFields(fields: seq[Field]): NimNode =
  # TODO rewrite this shit
  var enumFields = newSeqOfCap[EnumField](fields.len)

  for field in fields:
    if not (field.features.skipDeserializing or field.features.skipped):
      enumFields.add genEnumField(field)

      if field.isCase:
        for branch in field.branches:
          discard genFields(branch.fields)



proc generate(struct: Struct): NimNode =
  result = newStmtList()


macro makeDeserializable*(typ: typed{`type`}) =
  let struct = explore(typ)
  result = generate(struct)
