##[
Private module for the `serializeWith` pragma
]##

type
  SerializeWith*[T, Serializer] = object
    serializeProc: proc (self: T, serializer: Serializer)
    value: ptr T

proc serialize*[T, Serializer](self: SerializeWith[T, Serializer], serializer: Serializer) =
  self.serializeProc(self.value[], serializer)
