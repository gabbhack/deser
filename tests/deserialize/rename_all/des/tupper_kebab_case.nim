discard """
  output: '''
CAMEL-CASE
ANOTHER-CAMEL-CASE
  '''
"""

import deser

type
  TestToUpperKebabCase {.des, renameAll(des = rkUpperKebabCase).} = object
    camelCase: int
    anotherCamelCase: int

var t = TestToUpperKebabCase()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
