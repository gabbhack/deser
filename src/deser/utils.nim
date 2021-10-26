template asAddr*(ident: untyped, exp: untyped) =
  let temp = exp.addr
  template ident: untyped = temp[]
