#!/usr/bin/env lua
-- inspired by http://www.lua.org/pil/20.3.html

local function char_url_escape(c)
  return string.format('%%%02X', string.byte(c))
end

function string:strip()
  return self:gsub('^%s+', ''):gsub('%s+$', '')
end

function string:escape()
  s = self:gsub("([^A-Za-z0-9./:?&_-])", char_url_escape)
--  s = string.gsub(s, " ", "+")
  return s
end

io.write(io.read('*a'):strip():escape())
