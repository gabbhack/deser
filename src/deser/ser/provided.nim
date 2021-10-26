##[
Auxiliary functions that you can use when implementing `serialize`
]##

import std/options

import ../utils


proc isUnit(T: typedesc): bool {.compileTime.} =
  var ob = default T
  for _ in ob.fields():
    return false
  return true

type
  MapIter* = concept self  ## Type with pairs()
    self.pairs()

  SeqIter* = concept self  ## Type with items()
    self.items()
  
  UnitConcept* = concept type T  ## Type without fields
    T is object
    T.isUnit


proc serializeMapEntry*[Serializer; Key; Value](self: var Serializer, key: Key, v: Value) =
  self.serializeMapKey(key)
  self.serializeMapValue(v)

proc collectSeq*[Serializer; Iter: SeqIter](self: var Serializer, iter: Iter) =
  when compiles(iter.len):
    let length = some iter.len
  else:
    let length = none int
  
  asAddr state, self.serializeSeq(length)

  for value in iter:
    state.serializeSeqElement(value)

  state.endSeq()

proc collectMap*[Serializer; Iter: MapIter](self: var Serializer, iter: Iter) =
  when compiles(iter.len):
    let length = some iter.len
  else:
    let length = none int
  
  asAddr state, self.serializeMap(length)

  for key, value in iter:
    state.serializeMapEntry(key, value)
  
  state.endMap()

template collectSeq*[Serializer; Value](self: var Serializer, iter: iterable[Value]) =
  asAddr state, self.serializeSeq(none int)

  for value in iter:
    state.serializeSeqElement(value)

  state.endSeq()

template collectMap*[Serializer; Key; Value](self: var Serializer, iter: iterable[(Key, Value)]) =
  asAddr state, self.serializeMap(none int)

  for key, value in iter:
    state.serializeMapEntry(key, value)
  
  state.endMap()
