import ../private/parse {.all.}
import ../private/des {.all.}


macro makeDeserializable*(typ: typed{`type`}, public: static[bool] = false) =
  let struct = parse(typ)
  result = generate(struct, public)
