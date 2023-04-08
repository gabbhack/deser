from deser/macroutils/types import
  Field,
  isCase,
  branches,
  fields


func flatten(fields: seq[Field]): seq[Field] =
  var
    temp = newSeqOfCap[Field](fields.len)
    dedup = initHashSet[string]()

  for field in fields:
    if not field.isCase:
      temp.add field

    if field.isCase:
      if not field.features.untagged:
        temp.add initField(
          nameIdent=field.nameIdent,
          typeNode=field.typeNode,
          features=field.features,
          public=false,
          isCase=false,
          branches=newSeqOfCap[FieldBranch](0),
          nskEnumFieldSym=genSym(nskEnumField),
          nskTypeDeserializeWithSym=genSym(nskType),
          nskTypeSerializeWithSym=genSym(nskType)
        )
      for branch in field.branches:
        {.warning[UnsafeSetLen]: off.}
        temp.add flatten branch.fields
        {.warning[UnsafeSetLen]: on.}

  for field in temp:
    # It will become a problem when RFC 368 is implemented
    # https://github.com/nim-lang/RFCs/issues/368
    if not dedup.containsOrIncl field.nameIdent.strVal:
      result.add field

proc mergeToAllBranches*(self: var Field, another: Field) =
  ## Add `another` field to all branches of first field.
  doAssert self.isCase
  doAssert another.isCase

  # Compiler not smart enough
  {.warning[ProveField]:off.}
  for branch in self.branches.mitems:
    var hasCase = false
    for field in mitems(fields(branch)):
      if field.isCase:
        field.mergeToAllBranches another
        hasCase = true

    if not hasCase:
      branch.fields.add another
