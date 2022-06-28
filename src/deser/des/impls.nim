type
  NoneSeed*[Value] = object


proc deserialize*[D](self: NoneSeed, deserializer: D): self.Value {.noinit, inline.} =
  mixin deserialize

  result = self.Value.deserialize(deserializer)
