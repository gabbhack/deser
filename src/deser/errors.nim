type
  DeserError* = object of CatchableError

  FieldDeserializationError* = object of DeserError ##[
Field was not received or an error occurred during the deserialization of the field.
  ]##

  NoAnyVariantError* = object of DeserError ##[
Suitable branch was not found with the `untagged` case field.
  ]##
