import deser/[hacks, pragmas, templates, utils]
export hacks, pragmas, templates, utils

template forSerFields*(key: untyped, value: untyped, inOb: object | tuple | ref, actions: untyped) =
  ## Format developers should use this during serialization instead of fieldPairs
  actualForSerFields(`key`, `value`, `inOb`, `actions`, (), (), ())

template forDesFields*(key: untyped, value: untyped, inOb: var object | var tuple | ref, actions: untyped) =
  ## Format developers should use this during deserialization instead of fieldPairs
  actualForDesFields(`key`, `value`, `inOb`, `actions`, (), ())
