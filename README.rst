lua-dbus-type-parse
===============================================================================

A Lua DBus type signature parser.


Usage
==============================================================================

Minimal exemple:

.. code-block:: lua

    local parse = require 'parse'

    local tree = parse.parseSignature('a{s{u(iodai)}}')
    parse.prettyPrint(tree)


will display:

.. code-block::

    [array]
      [dictionary]
        [basic] string
        [dictionary]
          [basic] uint32
          [structure]
            [basic] int32
            [basic] path
            [basic] double
            [array]
              [basic] int32
