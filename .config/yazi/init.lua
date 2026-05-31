-- Per-letter pastel-rainbow on directory names, in the spirit of
-- ~/.local/bin/rainbow-prompt but deliberately duller/softer.
--
-- theme.toml can only apply one colour per entry, so we override the built-in
-- `Entity:highlights` component (the part that renders the file name) and, for
-- directories, emit one span per character coloured by a sine-wave palette:
--     r = sin(p + 0) * AMP + CENTER
--     g = sin(p + 2) * AMP + CENTER
--     b = sin(p + 4) * AMP + CENTER
-- with phase `p` sweeping SWEEP of a full cycle across the name (lime → orange →
-- pink → purple → blue → teal).
--
-- The two knobs control the mood:
--   CENTER  overall lightness  (lower = dimmer)
--   AMP     channel swing      (lower = more desaturated / greyer / duller)
-- The prompt uses CENTER 200 / AMP 55 (bright); these are pulled down to mute it.
--
-- Yazi applies per-span fg on top of the line's base style, so the gradient
-- wins over the `*/` rule's fg while still inheriting its `bold`.

local SWEEP = 0.6 -- fraction of a full colour cycle spread across the name
local CENTER = 180 -- overall lightness (was 200 in the prompt)
local AMP = 40 -- channel swing / saturation (was 55 in the prompt)

-- Split a string into UTF-8 characters (falls back to bytes if utf8 is absent).
local function chars_of(s)
	local out, pat = {}, utf8 and utf8.charpattern or "."
	for c in s:gmatch(pat) do out[#out + 1] = c end
	return out
end

local _orig_highlights = Entity.highlights

function Entity:highlights()
	local file = self._file
	-- Only rainbow real directories; everything else keeps default rendering
	-- (including search-keyword highlighting).
	if not (file.cha and file.cha.is_dir) then
		return _orig_highlights(self)
	end

	local chars = chars_of(file.name)
	local n = #chars
	if n == 0 then
		return _orig_highlights(self)
	end

	local freq = 2 * math.pi / (n > 1 and n or 1) * SWEEP
	local spans = {}
	for i = 1, n do
		local p = freq * (i - 1)
		local r = math.floor(math.sin(p + 0) * AMP + CENTER)
		local g = math.floor(math.sin(p + 2) * AMP + CENTER)
		local b = math.floor(math.sin(p + 4) * AMP + CENTER)
		spans[i] = ui.Span(chars[i]):fg(string.format("#%02x%02x%02x", r, g, b))
	end
	return ui.Line(spans)
end
