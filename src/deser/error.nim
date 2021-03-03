type
  DeserError* = object of CatchableError ##[
TODO
  ]##
  DuplicateFieldError* = object of DeserError ##[
TODO
  ]##
  UntaggemableError* = object of DeserError ##[
TODO
  ]##

  MissingFieldError* = object of UntaggemableError ##[
TODO
  ]##
  NoAnyVariantError* = object of UntaggemableError ##[
TODO
  ]##
