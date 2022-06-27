import std/strformat

import ../error

import unexpected


type
  DeserializationError* = object of DeserError ## \
    ## Error during deserialization

  InvalidType* = object of DeserializationError ## \
    ## Raised when a `Deserialize` receives a type different from what it was expecting
  
  InvalidValue* = object of DeserializationError ## \
    ## Raised when a `Deserialize` receives a value of the right type but that is wrong for some other reason

  InvalidLength* = object of DeserializationError ## \
    ## Raised when deserializing a sequence or map and the input data contains too many or too few elements

  UnknownField* = object of DeserializationError ## \
    ## Raised when a `Deserialize` enum type received a variant with an unrecognized name.

  MissingField* = object of DeserializationError ## \
    ## Raised when a `Deserialize` struct type expected to receive a required field with a particular name but that field was not present in the input

  DuplicateField* = object of DeserializationError ## \
    ## Raised when a `Deserialize` struct type received more than one of the same field
  
  UnknownUntaggedVariant* = object of DeserializationError ## \
    ## Raised when a `Deserialize` struct type cannot derive case variant


proc raiseInvalidType*(unexp: Unexpected, exp: auto) =
  raise newException(InvalidType, &"invalid type: {unexp}, expected {exp.expecting()}")


proc raiseInvalidValue*(unexp: Unexpected, exp: auto) =
  raise newException(InvalidValue, &"invalid value: {unexp}, expected {exp.expecting()}")


proc raiseInvalidLength*(unexp: uint, exp: auto) =
  raise newException(InvalidLength, &"invalid length {unexp}, expected {exp.expecting()}")


proc raiseUnknownField*(unexp: string) =
  raise newException(UnknownField, &"unknown field {unexp}, there are no fields")


proc raiseMissingField*(field: static[string]) =
  raise newException(MissingField, &"missing field `{field}`")


proc raiseDuplicateField*(field: static[string]) =
  raise newException(DuplicateField, &"duplicate field `{field}`")


proc raiseUnknownUntaggedVariant*(struct, caseField: static[string]) =
  raise newException(UnknownUntaggedVariant, &"not possible to derive value of case field `{field}` of struct `{struct}`")
