## Private module for the `serializeWith` pragma

type
  SerializeWith*[T, Serializer] = object
    serializeProc*: proc (self: T, serializer: var Serializer)
    value*: T

proc serialize*[T, Serializer](self: SerializeWith[T, Serializer], serializer: var Serializer) {.inline.} =
  self.serializeProc(self.value, serializer)
