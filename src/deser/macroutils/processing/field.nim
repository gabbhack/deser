from deser/macroutils/types import
  Field,
  isCase,
  branches,
  fields


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
