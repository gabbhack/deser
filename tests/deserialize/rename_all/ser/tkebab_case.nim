discard """
  output: '''
camel-case
another-camel-case
  '''
"""

import deser

type
  TestToKebabCase {.des, renameAll(rkKebabCase).} = object
    camelCase: int
    anotherCamelCase: int

var t = TestToKebabCase()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
