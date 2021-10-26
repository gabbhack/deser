template asAddr*(ident: untyped, exp: untyped) =
  ## Get result from procedures by addr
  when compiles(exp.addr):
    let temp = exp.addr
    template ident: untyped = temp[]
  else:
    var temp = exp
