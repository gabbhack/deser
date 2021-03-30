discard """
  output: '''
camelCase
anotherCamelCase
  '''
"""

import deser

type
  TestToKebabCase {.des, renameAll().} = object
    camelCase: int
    anotherCamelCase: int

var t = TestToKebabCase()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
