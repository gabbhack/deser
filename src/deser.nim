import deser/[hacks, pragmas, templates, utils]
export hacks, pragmas, templates, utils

template forSerFields*(key: untyped, value: untyped, inOb: object | tuple | ref, actions: untyped) =
  actualForSerFields(`key`, `value`, `inOb`, `actions`, (), (), ())

template forDesFields*(key: untyped, value: untyped, inOb: var object | var tuple | ref, actions: untyped) =
  actualForDesFields(`key`, `value`, `inOb`, `actions`, (), ())
