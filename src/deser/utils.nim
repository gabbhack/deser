template asAddr*(ident: untyped, exp: untyped) =
  when compiles(exp.addr):
    let temp = exp.addr
    template ident: untyped = temp[]
  else:
    var temp = exp
