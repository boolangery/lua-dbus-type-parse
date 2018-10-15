--- A DBus type signature parser.
---
--- input -> a(iis{si}i)
---
--- Output :
--- [array]
---   [structure]
---     [basic] int32
---     [basic] int32
---     [basic] string
---     [dictionary]
---       [basic] string
---       [basic] int32
---     [basic] int32
-- ----------------------------------------------------------------------------
-- Lexer                                                                     --
-- ----------------------------------------------------------------------------
--- DBus type signature tokens
local TOKENS = {
  BYTE        = 1,
  BOOLEAN     = 2,
  INT16       = 3,
  UINT16      = 4,
  INT32       = 5,
  UINT32      = 6,
  INT64       = 7,
  UINT64      = 8,
  DOUBLE      = 9,
  UNIX_FD     = 10,
  STRING      = 11,
  OBJECT_PATH = 12,
  SIGNATURE   = 13,
  ARRAY       = 14,
  O_STRUCT    = 15,
  C_STRUCT    = 16,
  VARIANT     = 17,
  O_DICT      = 18,
  C_DICT      = 19,
}

--- Dictionary of DBus type identifier to token
local PATTERN_TO_TOKEN = {
  ['y'] = TOKENS.BYTE,
  ['b'] = TOKENS.BOOLEAN,
  ['n'] = TOKENS.INT16,
  ['q'] = TOKENS.UINT16,
  ['i'] = TOKENS.INT32,
  ['u'] = TOKENS.UINT32,
  ['x'] = TOKENS.INT64,
  ['t'] = TOKENS.UINT64,
  ['d'] = TOKENS.DOUBLE,
  ['h'] = TOKENS.UNIX_FD,
  ['s'] = TOKENS.STRING,
  ['o'] = TOKENS.OBJECT_PATH,
  ['g'] = TOKENS.SIGNATURE,
  ['a'] = TOKENS.ARRAY,
  ['('] = TOKENS.O_STRUCT,
  [')'] = TOKENS.C_STRUCT,
  ['v'] = TOKENS.VARIANT,
  ['{'] = TOKENS.O_DICT,
  ['}'] = TOKENS.C_DICT,
}

--- Tokenize a DBus type signature.
--- @tparam string signature input dbus type signature
--- @treturn table an array of token
local function tokenize(signature)
  local tokens = {}
  for i = 1, #signature do
    local char = signature:sub(i, i)
    table.insert(tokens, PATTERN_TO_TOKEN[char])
  end
  return tokens
end

-- ----------------------------------------------------------------------------
-- Parser                                                                    --
-- ----------------------------------------------------------------------------
--- Define parse-tree node types
local NODES = {
  BASIC   = 1,
  VARIANT = 2,
  ARRAY   = 3,
  STRUCT  = 4,
  DICT    = 5,
}

--- Define basic node types
local BASIC_TYPES = {
  BYTE        = 1,
  BOOLEAN     = 2,
  INT16       = 3,
  UINT16      = 4,
  INT32       = 5,
  UINT32      = 6,
  INT64       = 7,
  UINT64      = 8,
  DOUBLE      = 9,
  UNIX_FD     = 10,
  STRING      = 11,
  OBJECT_PATH = 12,
  SIGNATURE   = 13,
}


--- Transform a token stream to a parse-tree.
---
--- Parse tree nodes are pure lua table:
---
---   byte      = {node = NODES.BASIC, type = BASIC_TYPES.BYTE}
---   boolean   = {node = NODES.BASIC, type = BASIC_TYPES.BOOLEAN}
---   int16     = {node = NODES.BASIC, type = BASIC_TYPES.INT16}
---   uint16    = {node = NODES.BASIC, type = BASIC_TYPES.UINT16}
---   int32     = {node = NODES.BASIC, type = BASIC_TYPES.INT32}
---   uint32    = {node = NODES.BASIC, type = BASIC_TYPES.UINT32}
---   int64     = {node = NODES.BASIC, type = BASIC_TYPES.INT64}
---   uint64    = {node = NODES.BASIC, type = BASIC_TYPES.UINT64}
---   double    = {node = NODES.BASIC, type = BASIC_TYPES.DOUBLE}
---   unix_fd   = {node = NODES.BASIC, type = BASIC_TYPES.UNIX_FD}
---   string    = {node = NODES.BASIC, type = BASIC_TYPES.STRING}
---   path      = {node = NODES.BASIC, type = BASIC_TYPES.OBJECT_PATH}
---   signature = {node = NODES.BASIC, type = BASIC_TYPES.SIGNATURE}
---
---   variant = {node = NODES.VARIANT}
---
---   array   = {node = NODES.ARRAY, type = <node>}
---   struct  = {node = NODES.STRUCT, types = {<node>, <node>, ..}
---   dict    = {node = NODES.DICT, key = <node>, value = <node>}
---
--- @tparam table tokens An array of tokens
--- @treturn table A parse-tree
local function tokensToParseTree(tokens)
  -- nodes operations
  local _root = {}  -- contains parse-tree nodes (root)
  local _contStack = {}  -- stack of opened container
  -- add a node to current parse-tree
  local function addNode(node)
    local container = _contStack[#_contStack]  -- get current opened container
    if container == nil then
      table.insert(_root, node)  -- no opened container, insert in root node
    else
      if container.node == NODES.ARRAY then
        container.type = node  -- set array children type
        -- close current array (only one type inside)
        addNode(table.remove(_contStack))
      elseif container.node == NODES.STRUCT then
        container.types = container.types or {}
        table.insert(container.types, node)  -- add children type to current structure
      elseif container.node == NODES.DICT then
        if container.key == nil then
          container.key = node
        elseif container.value == nil then
          container.value = node
        else
          error('DICT already filled')
        end
      else -- basic type, just append
        table.insert(_root, node)
      end
    end
  end

  -- containers operations
  -- tell the parse-tree that following nodes are going to
  -- be inserted in this container
  local function openContainer(type)
    -- push container node on stack
    table.insert(_contStack, {node = type})
  end
  -- tell the parse-tree to close the current container
  local function closeContainer()
    -- pop node from stack and return
    local node = table.remove(_contStack)
    addNode(node)
  end

  -- switch like dictionary
  local switch = {
    [TOKENS.BYTE]         = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.BYTE}) end,
    [TOKENS.BOOLEAN]      = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.BOOLEAN}) end,
    [TOKENS.INT16]        = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.INT16}) end,
    [TOKENS.UINT16]       = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.UINT16}) end,
    [TOKENS.INT32]        = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.INT32}) end,
    [TOKENS.UINT32]       = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.UINT32}) end,
    [TOKENS.INT64]        = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.INT64}) end,
    [TOKENS.UINT64]       = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.UINT64}) end,
    [TOKENS.DOUBLE]       = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.DOUBLE}) end,
    [TOKENS.UNIX_FD]      = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.UNIX_FD}) end,
    [TOKENS.STRING]       = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.STRING}) end,
    [TOKENS.OBJECT_PATH]  = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.OBJECT_PATH}) end,
    [TOKENS.SIGNATURE]    = function() addNode({node = NODES.BASIC, type = BASIC_TYPES.SIGNATURE}) end,

    [TOKENS.ARRAY]        = function() openContainer(NODES.ARRAY) end,
    [TOKENS.O_STRUCT]     = function() openContainer(NODES.STRUCT) end,
    [TOKENS.C_STRUCT]     = function() closeContainer(NODES.STRUCT) end,
    [TOKENS.VARIANT]      = function() addNode({node = NODES.VARIANT}) end,
    [TOKENS.O_DICT]       = function() openContainer(NODES.DICT) end,
    [TOKENS.C_DICT]       = function() closeContainer(NODES.DICT) end,
  }

  for _, token in ipairs(tokens) do
    switch[token]()
  end
  return _root
end

-- ----------------------------------------------------------------------------
-- Entry Point                                                               --
-- ----------------------------------------------------------------------------
local function parseSignature(signature)
  return tokensToParseTree(tokenize(signature))
end

local function visitTree(root, visitor)
  -- try to visit a visitor method
  local function tryVisit(method, node)
    if type(visitor[method]) == 'function' then
      visitor[method](node)
    else
      print('visitTree: mehod not found: ', method)
    end
  end

  if root.node == nil then  -- not a node
    for _, child in ipairs(root) do
      visitTree(child, visitor)
    end
  else
    if root.node == NODES.BASIC then
      tryVisit('enterBasic', root)
      tryVisit('leaveBasic', root)
    elseif root.node == NODES.VARIANT then
      tryVisit('enterVariant', root)
      tryVisit('leaveVariant', root)
    elseif root.node == NODES.DICT then
      tryVisit('enterDict', root)
      visitTree(root.key, visitor)
      visitTree(root.value, visitor)
      tryVisit('leaveDict', root)
    elseif root.node == NODES.STRUCT then
      tryVisit('enterStruct', root)
      for _, type in ipairs(root.types) do
        visitTree(type, visitor)
      end
      tryVisit('leaveStruct', root)
    elseif root.node == NODES.ARRAY then
      tryVisit('enterArray', root)
      visitTree(root.type, visitor)
      tryVisit('leaveArray', root)
    end
  end
end

-- ----------------------------------------------------------------------------
-- Pretty Print                                                              --
-- ----------------------------------------------------------------------------
local prettyPrint
do
  local NODES_TO_STR = {
    [NODES.BASIC]   = 'basic',
    [NODES.VARIANT] = 'variant',
    [NODES.ARRAY]   = 'array',
    [NODES.STRUCT]  = 'structure',
    [NODES.DICT]    = 'dictionary',
  }
  local BASIC_TYPES_TO_STR = {
    [BASIC_TYPES.BYTE]        = 'byte',
    [BASIC_TYPES.BOOLEAN]     = 'boolean',
    [BASIC_TYPES.INT16]       = 'int16',
    [BASIC_TYPES.UINT16]      = 'uint16',
    [BASIC_TYPES.INT32]       = 'int32',
    [BASIC_TYPES.UINT32]      = 'uint32',
    [BASIC_TYPES.INT64]       = 'int64',
    [BASIC_TYPES.UINT64]      = 'uint64',
    [BASIC_TYPES.DOUBLE]      = 'double',
    [BASIC_TYPES.UNIX_FD]     = 'unix-fd',
    [BASIC_TYPES.STRING]      = 'string',
    [BASIC_TYPES.OBJECT_PATH] = 'path',
    [BASIC_TYPES.SIGNATURE]   = 'signature',
  }
   
  prettyPrint = function(tree)
    local _level = 0
    local function _p(str)
      print(('  '):rep(_level) .. str)
    end
    local _visitor = {
      enterBasic    = function(node)
      end,

      leaveBasic    = function(node)
        _p(('[%s] %s'):format(NODES_TO_STR[node.node], BASIC_TYPES_TO_STR[node.type]))
      end,

      enterVariant  = function(node)
        _p(('[%s]'):format(NODES_TO_STR[node.node]))
      end,

      leaveVariant  = function(node)
      end,

      enterDict     = function(node)
        _p(('[%s]'):format(NODES_TO_STR[node.node]))
        _level = _level + 1
      end,

      leaveDict     = function(node)
        _level = _level - 1
      end,

      enterStruct   = function(node)
        _p(('[%s]'):format(NODES_TO_STR[node.node]))
        _level = _level + 1
      end,

      leaveStruct   = function(node)
        _level = _level - 1
      end,

      enterArray    = function(node)
        _p(('[%s]'):format(NODES_TO_STR[node.node]))
        _level = _level + 1
      end,

      leaveArray    = function(node)
        _level = _level - 1
      end,
    }
    visitTree(tree, _visitor)
  end
end


return {
  NODES          = NODES,
  BASIC_TYPES    = BASIC_TYPES,
  parseSignature = parseSignature,
  visitTree      = visitTree,
  prettyPrint    = prettyPrint
}
