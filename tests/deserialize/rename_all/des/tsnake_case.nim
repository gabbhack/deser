discard """
  output: '''
camel_case
another_camel_case
  '''
"""

import deser

type
  TestToSnakeCase {.des, renameAll(des = rkSnakeCase).} = object
    camelCase: int
    anotherCamelCase: int

var t = TestToSnakeCase()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
