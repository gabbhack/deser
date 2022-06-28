import std/[macros]

import ../private/parse {.all.}
import ../private/des {.all.}


macro makeDeserializable*(typ: typed{`type`}) =
  let struct = parse(typ)
  result = generate(struct)
