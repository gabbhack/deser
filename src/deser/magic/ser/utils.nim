{.push used.}
template asAddr(ident: untyped, exp: untyped): untyped =
  ## Get result from procedures by addr
  when compiles(addr(exp)):
    let temp = addr(exp)
    template ident: untyped = temp[]
  else:
    var ident = exp
{.pop.}
