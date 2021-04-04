discard """
  output: '''
Data did not match any variant of `untagged` discriminator `kind` of type `Test`
  '''
"""

import
  deser

type
  TestKind = enum
    True, False

  Test {.des.} = object
    case kind {.untagged.}: TestKind
    of True:
      t: string
    of False:
      f: bool

var t = Test()

try:
  startDes t:
    forDes key, value, t:
      discard
except NoAnyVariantError:
  echo getCurrentExceptionMsg()
