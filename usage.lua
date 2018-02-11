local parse = require 'parse'

local tree = parse.parseSignature('a{s{u(iodai)}}')
parse.prettyPrint(tree)
