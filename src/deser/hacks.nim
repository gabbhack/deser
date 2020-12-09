import macros

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

template checkedObj*(inOb: object | tuple | ref | var object | var tuple): untyped =
  ## for internal use only
  when inOb is ref:
    # https://github.com/nim-lang/Nim/issues/8456
    inOb[]
  else:
    inOb