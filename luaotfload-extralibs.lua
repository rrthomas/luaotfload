if not modules then modules = { } end modules ["extralibs"] = {
    version   = 2.200,
    comment   = "companion to luaotfload.lua",
    author    = "Hans Hagen, Philipp Gesang",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "GPL v.2.0",
}

-- extralibs: set up an emulation layer to load additional Context
--            libraries

--===================================================================--
---                             PREPARE
--===================================================================--

local getmetatable    = getmetatable
local require         = require
local select          = select
local setmetatable    = setmetatable
local tonumber        = tonumber

local texattribute    = tex.attribute

local new_node        = node.new
local copy_node       = node.copy

-----------------------------------------------------------------------
--- namespace
-----------------------------------------------------------------------

--- The “typesetters” namespace isn’t bad at all; there is no need
--- to remove it after loading.

typesetters              = typesetters or { }
local typesetters        = typesetters
typesetters.kerns        = typesetters.kerns or { }
local kerns              = typesetters.kerns
kerns.mapping            = kerns.mapping or { }
kerns.factors            = kerns.factors or { }

local namespace          = "kern" --- <= attribute <= plugin.name
local callback_name      = "typesetters.kerncharacters"

-----------------------------------------------------------------------
--- node-ini
-----------------------------------------------------------------------

nodes              = nodes or { } --- should be present with luaotfload
local bothways     = function (t) return table.swapped (t, t) end

nodes.kerncodes = bothways({
  [0] = "fontkern",
  [1] = "userkern",
  [2] = "accentkern",
})

nodes.skipcodes = bothways({
  [  0] = "userskip",
  [  1] = "lineskip",
  [  2] = "baselineskip",
  [  3] = "parskip",
  [  4] = "abovedisplayskip",
  [  5] = "belowdisplayskip",
  [  6] = "abovedisplayshortskip",
  [  7] = "belowdisplayshortskip",
  [  8] = "leftskip",
  [  9] = "rightskip",
  [ 10] = "topskip",
  [ 11] = "splittopskip",
  [ 12] = "tabskip",
  [ 13] = "spaceskip",
  [ 14] = "xspaceskip",
  [ 15] = "parfillskip",
  [ 16] = "thinmuskip",
  [ 17] = "medmuskip",
  [ 18] = "thickmuskip",
  [100] = "leaders",
  [101] = "cleaders",
  [102] = "xleaders",
  [103] = "gleaders",
})

-----------------------------------------------------------------------
--- node-res
-----------------------------------------------------------------------

nodes.pool        = nodes.pool or { }
local pool        = nodes.pool

local kern        = new_node("kern", nodes.kerncodes.userkern)
local glue_spec   = new_node "glue_spec"

pool.kern = function (k)
  local n = copy_node(kern)
  n.kern = k
  return n
end

pool.gluespec = function (width, stretch, shrink, 
                          stretch_order, shrink_order)
  local s = copy_node(glue_spec)
  if width         then s.width         = width         end
  if stretch       then s.stretch       = stretch       end
  if shrink        then s.shrink        = shrink        end
  if stretch_order then s.stretch_order = stretch_order end
  if shrink_order  then s.shrink_order  = shrink_order  end
  return s
end

pool.glue = function (width, stretch, shrink,
                      stretch_order, shrink_order)
  local n = new_node"glue"
  if not width then
    -- no spec
  elseif width == false or tonumber(width) then
    local s = copy_node(glue_spec)
    if width         then s.width         = width         end
    if stretch       then s.stretch       = stretch       end
    if shrink        then s.shrink        = shrink        end
    if stretch_order then s.stretch_order = stretch_order end
    if shrink_order  then s.shrink_order  = shrink_order  end
    n.spec = s
  else
    -- shared
    n.spec = copy_node(width)
  end
  return n
end

-----------------------------------------------------------------------
--- font-hsh
-----------------------------------------------------------------------
--- some initialization resembling font-hsh
local fonthashes         = fonts.hashes
local identifiers        = fonthashes.identifiers --- was: fontdata
local chardata           = fonthashes.characters
local quaddata           = fonthashes.quads
local markdata           = fonthashes.marks
local parameters         = fonthashes.parameters

--- ('a, 'a) hash -> (('a, 'a) hash -> 'a -> 'a) -> ('a, 'a) hash
local setmetatableindex = function (t, f)
  local mt = getmetatable(t)
  if mt then
    mt.__index = f
  else
    setmetatable(t, { __index = f })
  end
  return t
end

if not parameters then
  parameters = { }
  setmetatableindex(parameters, function(t, k)
    if k == true then
      return parameters[currentfont()]
    else
      local parameters = identifiers[k].parameters
      t[k] = parameters
      return parameters
    end
  end)
  fonthashes.parameters = parameters
end

if not chardata then
  chardata = { }
  setmetatableindex(chardata, function(t, k)
    if k == true then
      return chardata[currentfont()]
    else
      local characters = identifiers[k].characters
      t[k] = characters
      return characters
    end
  end)
  fonthashes.characters = chardata
end

if not quaddata then
  quaddata = { }
  setmetatableindex(quaddata, function(t, k)
    if k == true then
      return quads[currentfont()]
    else
      local parameters = parameters[k]
      local quad = parameters and parameters.quad or 0
      t[k] = quad
      return quad
    end
  end)
  fonthashes.quads = quaddata
end

if not markdata then
  markdata = { }
  setmetatableindex(markdata, function(t, k)
    if k == true then
      return marks[currentfont()]
    else
      local resources = identifiers[k].resources or { }
      local marks = resources.marks or { }
      t[k] = marks
      return marks
    end
  end)
  fonthashes.marks = markdata
end

--- next stems from the multilingual interface
interfaces                = interfaces or { }
interfaces.variables      = interfaces.variables or { }
interfaces.variables.max  = "max"

-----------------------------------------------------------------------
--- attr-ini
-----------------------------------------------------------------------

attributes = attributes or { } --- to be removed with cleanup

local hidden = {
  a_kerns     = luatexbase.new_attribute("typo-krn:a_kerns",    true),
  a_fontkern  = luatexbase.new_attribute("typo-krn:a_fontkern", true),
}

attributes.private = attributes.private or function (attr_name)
  local res = hidden[attr_name]
  if not res then
    res = luatexbase.new_attribute(attr_name)
  end
  return res
end

if luatexbase.get_unset_value then
  attributes.unsetvalue = luatexbase.get_unset_value()
else -- old luatexbase
  attributes.unsetvalue = (luatexbase.luatexversion < 37) and -1
                       or -2147483647
end

-----------------------------------------------------------------------
--- luat-sto
-----------------------------------------------------------------------

--- Storage is so ridiculously well designed in Context it’s a pity
--- we can’t just force every package author to use it.

storage           = storage or { }
storage.register  = storage.register or function (...)
  local t = { ... }
  --- sorry
  return t
end

-----------------------------------------------------------------------
--- node-fin
-----------------------------------------------------------------------

local plugin_store = { }

local installattributehandler = function (plugin)
  --- Context has some load() magic here.
  plugin_store[plugin.name] = plugin.processor
end

nodes.installattributehandler = installattributehandler

-----------------------------------------------------------------------
--- node-tsk
-----------------------------------------------------------------------

nodes.tasks               = nodes.tasks or { }
nodes.tasks.enableaction  = function () end

-----------------------------------------------------------------------
--- core-ctx
-----------------------------------------------------------------------

commands = commands or { }

--===================================================================--
---                              LOAD
--===================================================================--

--- we should be ready at this moment to insert the library

--require "luaotfload-typo-krn"
require "luaotfload-letterspace" --- simplified

--===================================================================--
---                              CLEAN
--===================================================================--
--- interface
-----------------------------------------------------------------------

local factors           = kerns.factors
local mapping           = kerns.mapping
local unsetvalue        = attributes.unset_value
local process_kerns     = plugin_store.kern

local kernfont          = typesetters.kernfont

local kerncharacters = function (head)
  return process_kerns("kerns", hidden.a_kerns, head)
end

--- callback wrappers
local add_kern_processor = function (...)
  for i=1, select("#", ...) do
    luatexbase.add_to_callback(
      select(i, ...), kernfont.handler, callback_name
    )
  end
end
local remove_kern_processor = function (...)
  for i=1, select("#", ...) do
    luatexbase.remove_from_callback(
      select(i, ...), callback_name
    )
  end
end

--- we use the same callbacks as a node processor in Context
local enablecharacterkerning = function ( )
  add_kern_processor("pre_linebreak_filter", "hpack_filter")
end

local disablecharacterkerning = function ( )
  remove_kern_processor("pre_linebreak_filter", "hpack_filter")
end

--kerns.enablecharacterkerning    = enablecharacterkerning
--kerns.disablecharacterkerning   = disablecharacterkerning
kernfont.enablecharacterkerning    = enablecharacterkerning
kernfont.disablecharacterkerning   = disablecharacterkerning

local enabled = false --- callback state

local initializekerning = function (tfmdata, factor)
  if factor ~= "max" then
    factor = tonumber(factor) or 0
  end
  if factor == "max" or factor ~= 0 then
    local fontproperties = tfmdata.properties
    if fontproperties then
      --- hopefully this field stays unused otherwise
      fontproperties.kerncharacters = factor
    end
    if not enabled then
      enablecharacterkerning()
      enabled = true
    end
  end
end

local otffeatures = fonts.constructors.newfeatures "otf"
otffeatures.register {
    name        = "kerncharacters",
    description = "kerncharacters",
    initializers = {
        base = initializekerning,
        node = initializekerning,
    }
}

-----------------------------------------------------------------------
--- options
-----------------------------------------------------------------------

kerns.keepligature = false --- supposed to be of type function
kerns.keeptogether = false --- supposed to be of type function

-----------------------------------------------------------------------
--- erase fake Context layer
-----------------------------------------------------------------------

attributes     = nil
--commands       = nil  --- used in lualibs
storage        = nil    --- not to confuse with utilities.storage
nodes.tasks    = nil

collectgarbage"collect"

--[[example--

\input luaotfload.sty
\def\setcharacterkerning#1{% #1 factor : float
  \directlua{typesetters.kerns.set(0.618)}%
}
%directlua{typesetters.kerns.enablecharacterkerning()}

\font\iwona       = "name:Iwona:mode=node"                at 42pt
\font\lmregular   = "name:Latin Modern Roman:mode=node"   at 42pt

{\iwona
 foo
 {\setcharacterkerning{0.618}%
  bar}
 baz}

{\lmregular
 foo {\setcharacterkerning{0.125}ff fi ffi fl Th} baz}

{\lmregular
 \directlua{ %% I’m not exactly sure how those work
    typesetters.kerns.keepligature = function (start)
      print("[liga]", start)
      return true
    end
    typesetters.kerns.keeptogether = function (start)
      print("[keeptogether]", start)
      return true
    end}%
 foo {\setcharacterkerning{0.125}ff fi ffi fl Th} baz}

\bye
--example]]--

-- vim:ts=2:sw=2:expandtab