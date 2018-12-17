pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

--[[
render layers:
]]

-- useful no-op function
function noop() end

-- returns the second argument if condition is truthy, otherwise returns the third argument
function ternary(condition, if_true, if_false)
  return condition and if_true or if_false
end

-- constants
local controllers = { 1, 0 }
local bg_color = 0

-- effect vars
local game_frames
local freeze_frames
local screen_shake_frames

-- input vars
local buttons
local button_presses

-- entity vars
local entities
local entity_classes = {
  snow_layer = {
    init = function(self)
      self.snowflakes = {
        { x = 50, y = 29 }
      }
    end,
    update = function(self)
      -- add new snowflakes
      add(self.snowflakes, {
        x = rnd_int(-5, 131),
        y = 29  
      })
      -- update all snowflakes
      local i
      for i = 1, #self.snowflakes do
        local snowflake = self.snowflakes[i]
        snowflake.y += 0.4
      end
      -- remove snowflakes that hit the ground
      filter_list(self.snowflakes, function(snowflake)
        return snowflake.y < 83
      end)
    end,
    draw = function(self)
      -- draw all snowflakes
      local i
      for i = 1, #self.snowflakes do
        local snowflake = self.snowflakes[i]
        sspr2(6, 92, 3, 3, snowflake.x, snowflake.y)
      end
    end
  }
}

function _init()
  -- init vars
  game_frames = 0
  freeze_frames = 0
  screen_shake_frames = 0
  buttons = { {}, {} }
  button_presses = { {}, {} }
  entities = {}
  -- spawn initial entities
  spawn_entity('snow_layer', 0, 0)
end

function _update()
  -- keep track of counters
  local game_is_running = freeze_frames <= 0
  freeze_frames = decrement_counter(freeze_frames)
  if game_is_running then
    game_frames = increment_counter(game_frames)
    screen_shake_frames = decrement_counter(screen_shake_frames)
  end
  -- keep track of button presses
  local p
  for p = 1, 2 do
    local i
    for i = 0, 5 do
      button_presses[p][i] = btn(i, controllers[p]) and not buttons[p][i]
      buttons[p][i] = btn(i, controllers[p])
    end
  end
  -- update each entity
  local entity
  for entity in all(entities) do
    if entity.is_freeze_frame_immune or game_is_running then
      if decrement_counter_prop(entity, "frames_to_death") then
        entity:die()
      else
        increment_counter_prop(entity, "frames_alive")
        entity:update()
      end
    end
  end
  -- remove dead entities
  filter_list(entities, function(item)
    return item.is_alive
  end)
  -- sort entities for rendering
  sort_list(entities, is_rendered_on_top_of)
end

function _draw()
  -- shake the screen
  local screen_offet_x = x
  if freeze_frames <= 0 and screen_shake_frames > 0 then
    screen_offet_x = ceil(screen_shake_frames / 3) * (game_frames % 2 * 2 - 1)
  end
  camera(screen_offet_x)
  -- clear the screen
  cls(bg_color)
  -- draw the background
  pal(4, 0)
  sspr2(64, 71, 64, 57, 0, 32)
  sspr2(64, 71, 64, 57, 63, 32, true)
  -- draw background trees
  sspr2(9, 92, 9, 9, 32, 69) -- left
  sspr2(53, 69, 11, 23, 0, 53) -- far left
  sspr2(2, 101, 16, 27, 111, 49) -- far right
  -- draw snowball panes
  pal(11, 12)
  sspr2(18, 92, 46, 36, 7, 84)
  pal(11, 8)
  sspr2(18, 92, 46, 36, 74, 84, true)
  -- draw score tally marks
  pal(11, 12)
  sspr2(50, 72, 3, 20, 24, 10)
  sspr2(50, 72, 3, 20, 30, 10)
  pal(11, 1)
  sspr2(50, 72, 3, 20, 36, 10)
  pal(11, 8)
  sspr2(50, 72, 3, 20, 100, 10)
  pal(11, 2)
  sspr2(50, 72, 3, 20, 94, 10)
  sspr2(50, 72, 3, 20, 88, 10)
  -- draw each entity
  local entity
  for entity in all(entities) do
    if entity.is_visible and entity.frames_alive >= entity.hidden_frames then
      entity:draw(entity.x, entity.y)
      pal()
      fillp()
    end
  end
  -- cover up the rightmost column of pixels
  line(127, 0, 127, 127, 0)
end

-- spawns an instance of the given class
function spawn_entity(class_name, x, y, args, skip_init)
  local class_def = entity_classes[class_name]
  local entity
  if class_def.extends then
    entity = spawn_entity(class_def.extends, x, y, args, true)
  else
    -- create a default entity
    entity = {
      -- life cycle vars
      is_alive = true,
      frames_alive = 0,
      frames_to_death = 0,
      -- position vars
      x = x or 0,
      y = y or 0,
      vx = 0,
      vy = 0,
      width = 8,
      height = 8,
      -- render vars
      render_layer = 5,
      is_visible = true,
      hidden_frames = 0,
      -- functions
      init = noop,
      update = function(self)
        self:apply_velocity()
      end,
      apply_velocity = function(self)
        self.x += self.vx
        self.y += self.vy
      end,
      center_x = function(self)
        return self.x + self.width / 2
      end,
      center_y = function(self)
        return self.y + self.height / 2
      end,
      -- draw functions
      draw = noop,
      draw_outline = function(self, color)
        rect(self.x + 0.5, self.y + 0.5, self.x + self.width - 0.5, self.y + self.height - 0.5, color or 7)
      end,
      -- life cycle functions
      die = function(self)
        if self.is_alive then
          self.is_alive = false
          self:on_death()
        end
      end,
      despawn = function(self)
        self.is_alive = false
      end,
      on_death = noop
    }
  end
  -- add class-specific properties
  entity.class_name = class_name
  local key, value
  for key, value in pairs(class_def) do
    entity[key] = value
  end
  -- override with passed-in arguments
  for key, value in pairs(args or {}) do
    entity[key] = value
  end
  if not skip_init then
    -- add it to the list of entities
    add(entities, entity)
    -- initialize the entitiy
    entity:init()
  end
  -- return the new entity
  return entity
end

-- wrappers for input methods
function btn2(button_num, player_num)
  return buttons[player_num][button_num]
end
function btnp2(button_num, player_num, consume_press)
  if button_presses[player_num][button_num] then
    if consume_press then
      button_presses[player_num][button_num] = false
    end
    return true
  end
end

-- bubble sorts a list
function sort_list(list, func)
  local i
  for i=1, #list do
    local j = i
    while j > 1 and func(list[j - 1], list[j]) do
      list[j], list[j - 1] = list[j - 1], list[j]
      j -= 1
    end
  end
end

-- removes all items in the list that don't pass the criteria func
function filter_list(list, func)
  local item
  for item in all(list) do
    if not func(item) then
      del(list, item)
    end
  end
end

-- apply camera shake and freeze frames
function shake_and_freeze(s, f)
  screen_shake_frames = max(screen_shake_frames, s)
  freeze_frames = max(freeze_frames, f or 0)
end

-- returns true if a is rendered on top of b
function is_rendered_on_top_of(a, b)
  return ternary(a.render_layer == b.render_layer, a:center_y() > b:center_y(), a.render_layer > b.render_layer)
end

-- check to see if two rectangles are overlapping
function rects_overlapping(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

-- helper methods for incrementing/decrementing counters while avoiding the integer limit
function increment_counter(n)
  return ternary(n>32000, 20000, n+1)
end
function increment_counter_prop(obj, key)
  obj[key] = increment_counter(obj[key])
end
function decrement_counter(n)
  return max(0, n-1)
end
function decrement_counter_prop(obj, key)
  local initial_value = obj[key]
  obj[key] = decrement_counter(initial_value)
  return initial_value > 0 and initial_value <= 1
end

-- generates a random integer between min_val and max_val, inclusive
function rnd_int(min_val, max_val)
  return flr(min_val + rnd(1 + max_val - min_val))
end

-- finds the distance between two points
function calc_distance(x1, y1, x2, y2)
  local dx = mid(-100, x2 - x1, 100)
  local dy = mid(-100, y2 - y1, 100)
  return sqrt(dx * dx + dy * dy), dx, dy
end

-- wrappers for drawing functions
function pset2(x, y, ...)
  pset(x + 0.5, y + 0.5, ...)
end
function print2(text, x, y, ...)
  print(text, x + 0.5, y + 0.5, ...)
end
function print2_center(text, x, y, ...)
  print(text, x - 2 * #("" .. text) + 0.5, y + 0.5, ...)
end
function spr2(sprite, x, y, ...)
  spr(sprite, x + 0.5, y + 0.5, 1, 1, ...)
end
function sspr2(sx, sy, sw, sh, x, y, flip_h, flip_y, sw2, sh2)
  sspr(sx, sy, sw, sh, x + 0.5, y + 0.5, sw2 or sw, sh2 or sh, flip_h, flip_y)
end
function rectfill2(x, y, width, height, ...)
  rectfill(x + 0.5, y + 0.5, x + width - 0.5, y + height - 0.5, ...)
end

__gfx__
00000033300000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222220123
03000333300000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222224567
377003333000000002222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222289ab
3770033330000000022222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222cdef
33033bbbb33333333222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
33333bbbb33333330222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
33333333333000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00003333330000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00003333330000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00003333330000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00003333333000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00003333333000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00003330333300000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00003330033360000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
06063336066660000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00666666000000000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000000333000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000033b333300222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000333b333300222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000333b333300222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00033333b33300222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00033333333330222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
60633333333330222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
06666333303336222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000033360660222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000006600000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000000330000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000000b3333000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000003b3333000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
000033b3333300222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
0000333bb33300222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00033333333330222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00033333333330222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
60633333337730222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
06666633337736222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000006333360222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000000660000222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
2222222222222222222222222222222222222222222222222222200d000000002222222222222222222222222222222222222222222222222222222222222222
2222222222222222222222222222222222222222222222222222200dd00000002222222222222222222222222222222222222222222222222222222222222222
222222222222222222222222222222222222222222222222222220ddd000000044dddddddddddddddddddddddddddd2444444444444444444444444444444444
22222222222222222222222222222222222222222222222222b000d7d000000044dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
22222222222222222222222222222222222222222222222222bb00dd7d00000044dddddddddddddd6dddddddddddddddddddddddddddddddddddddddddddddd6
22222222222222222222222222222222222222222222222222bb00ddddd0000044ddddddddddddddddddddddddddd6dddddddddddddddddddddddddddddddddd
22222222222222222222222222222222222222222222222222bb00dddd00000044dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
22222222222222222222222222222222222222222222222222bbb07ddddd000044ddd6dddddddddddddddddddddddddddddddddddd6ddddddddddd6ddddddddd
22222222222222222222222222222222222222222222222222bbb0dddd00000044ddddddddd6ddddddddddd6ddddddddddd6dddddddddddddddddddddddddddd
22222222222222222222222222222222222222222222222222bbb0ddddd0000044dddddddddddddddddddddddddddddddddddddd6ddd6ddd6ddd6ddd6ddd6dd6
22222222222222222222222222222222222222222222222222bbb0d77ddd000044ddddddd6ddd6ddd6ddd6ddd6ddd6ddd6dddd6ddd6ddd6ddd6ddd6ddd6ddd6d
22222222222222222222222222222222222222222222222222bbb0dd77d00000446ddd6dddd6ddd6ddd6ddd6ddd6ddd6ddd6d6d6d6d6d6d6d6d6d6d6d6d6d6d6
22222222222222222222222222222222222222222222222222bbb0dddd7d000044dd6ddd6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d
22222222222222222222222222222222222222222222222222bbb0ddddddd00044d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d666d6666666d6666666d66666
22222222222222222222222222222222222222222222222222bbb0dddddddd00446d6d6d666d6666666d6666666d6666666d666d666666d6666666d66666666d
22222222222222222222222222222222222222222222222222bbb0dddddd0000446666666666666d6666666d6666666d66666666666666666666666666666666
22222222222222222222222222222222222222222222222222bbb0dd6dddd0004466d66666666666666666666666666666666666666666666666666666666666
22222222222222222222222222222222222222222222222222bbbdddd66dddd044666666666666666666666666666666666666666666d66666666666666d6666
22222222222222222222222222222222222222222222222222bbbddddd7d000044666666666666666d66666666666d6666666666666666666666666666666666
22222222222222222222222222222222222222222222222222bbbddddddd77d04d6666d666666666666666666666666666666666666666666666666666666666
222222222222222222222222222222222222222222222222220bbddddddddddd46666666666666666666666666666666666666666666666666d6666666666666
222222222222222222222222222222222222222222222222220bbddd000000004666666666666666666666666666666666666666666666666666666666666666
2222222222222222222222222222222222222222222222222200b7d0000000004666666666666666666666666666666666666666666666666666666666666666
2222220000000d000000000000000004444444444444444444444444444444444666666666666666666666666666666666666666666666666666666666666666
2222220700000dd00044444444444444444444444444444444444444444444444666666666666d66666666666666666666666666666666666666666666666666
222222000000ddd00044444444444444444677777777777676666666666666444666666666666666666666666666666666666666666666666666666666666666
22222207000ddd7d0044666666667776777777777777777777777767676666444666666666666666666666666666666666666666666666666666666666666666
222222777000d6d7d0446667767777777777777777777777777777777676664446666666666666666666666666666d6666666666666666666666666666666666
2222220700dd6ddd0044667677777777777777777777777777777777776766444666666666666666666666666666666666666666666666666666666666666666
22222270700d7dddd044676777777777777777777777777777777777766676444666666666666666666666666666666666666666666666666666666666666666
2222220700d7ddddd044667677777777777777777777777777777777776766444666666666666666666666666666666666666666666666666666666666666666
22222270777d7d7d7d44677777777777777777bbbbbbbb7777777777777776444666666666666666666666666666666666666666666666666666666666666666
220000000000000d00446777777777777777bbbbbbbbbbbb77777777777776444666666666666666666666666666666666666666666666666666666666666666
220000000000000dd044677777777777777bbbbbbbbbbbbbb7777777777776444666666666666666666666666666666666666666666666666666666666666666
22000000000000d7d04467777777777777bbbbbbbbbbbbbbbb777777777777444666666666666666666666666666666666666666666666666666666666666666
2200000000000d76d0446777777777777bbbbbb777777bbbbbb77777777776444666666666666666666666666666666666666666666666666666666666666666
22000000000000ddd044677777777777bbbbb7777777777bbbbb7777777777444666666666666666666666666666666666666666666666666666666666666666
2200000000000dddd044777777777777bbbb777777777777bbbb7777777777444666666666666666766666666666666666666666666666666666666666666666
220000000000d77dd04467777777777bbbbb777777777777bbbbb777777777444666666666666666666666666666676666666666666666666666666666666666
22000000000d77ddd04477777777777bbbb77777777667777bbbb77777777744d666666666666666666666666666666666666666666666666666666666666667
2200000000ddd67dd04477777777777bbbb77777777776777bbbb777777777446666676666666666666666666666666666666666666666666666666666666666
220000000000ddddd04477777777777bbbb77777777777777bbbb777777777446666666666676666666666676666666666666666666666666666666666666666
2200000000ddddddd04477777777777bbbb77777777777777bbbb777777777446666666666666666666666666666666666666666667666666666667666666666
220000000d7dddd7d00077777777777bbbb67777777777777bbbb777777777606666666667666766676667666766676667676666666666666666666666666666
2200000d77dddd77d00077777777777bbbb67777777777777bbbb777777777706676667666676667666766676667666766666666766676667666766676667667
22000000dddddd7dd00077777777777bbbbb677777777777bbbbb777777777707666766676767676767676767676767676766676667666766676667666766676
220000dd0dddd7ddd000777777777777bbbb666777777777bbbb7777777777707777777777777767676767676767676767676767676767676767676767676767
22000dd0dddd6dddd000777777777777bbbbb6667777777bbbbb7777777777607777777777777777777777777777777777767676767676767676767676767676
220000d7dd6dddddd0007777777777777bbbbbb666677bbbbbb77777777777707777777777777777777777777777777777777777777777777777777777777777
22000d7dddddd7ddd00077777777777777bbbbbbbbbbbbbbbb777777777776607777777777777777777777777777777777777777777777777777777777777777
2200dddddddd77ddd000677777777777777bbbbbbbbbbbbbb7777777777767607777777777777777777777777777777777777777777777777777777777777777
2200000d7ddd7dddd0007777777777777777bbbbbbbbbbbb77777777777776607777777777777777777777777777777777777777777777777777777777777777
220000d7ddddddddd000677777777777777777bbbbbbbb7777777777777776607777777777777777777777777777777777777777777777777777777777777777
2200d77d77dddddddd00677677777777777777777777777777777777777767607777777777777777777777777777777777777777777777777777777777777777
220d77dd7ddddddddd00676667777777777777777777777777777777777676607777777777777777777777777777777777777777777777777777777777777777
22dddd0ddddddddddd00667677777777777777777777777777777777676766607777777777777777777777777777777777777777777777777777777777777777
220000000ddddddddd00676767777777777777777777777777777776666666607777777777777777777777777666666666666666666666666666666666666666
220000000000000ddd00667676777777777777777777777777777600000000006666666666666666666666666666666666666d44444444444444444444444444
220000000000000ddd006666666677777776000000000000000000000000000066666666666d4444444444444444444444444444444444444444444444444444
