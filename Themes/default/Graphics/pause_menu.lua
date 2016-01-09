gameplay_pause_count= 0

local pause_buttons= {Start= true, Select= true, Back= true}
local pause_double_tap_time= .5
local pause_press_times= {}
local screen_gameplay= false
local menu_items= {[PLAYER_1]= {}, [PLAYER_2]= {}}
local menu_frames= {}
local menu_choices= {
	"continue_playing",
	"restart_song",
	"forfeit_song",
}
if GAMESTATE:IsCourseMode() then
	menu_choices= {
		"continue_playing",
		"skip_song",
		"forfeit_course",
	}
end
local menu_spacing= 32
local menu_bg_width= _screen.w * .4
local menu_text_width= _screen.w * .35
local menu_x= {[PLAYER_1]= _screen.w*.25, [PLAYER_2]= _screen.w*.75}
local menu_y= _screen.cy - (#menu_choices * .5 * menu_spacing)
local current_menu_choice= {}
local menu_is_showing= {}
local enabled_players= {}

local function create_menu_item(pn, x, y, item_name)
	return Def.BitmapText{
		Font= "Common Normal", Text= THEME:GetString("PauseMenu", item_name),
		InitCommand= function(self)
			self:xy(x, y)
			table.insert(menu_items[pn], self)
			self:playcommand("LoseFocus")
		end,
		LoseFocusCommand= function(self)
			self:stopeffect():rotationz(0)
		end,
		GainFocusCommand= function(self)
			self:wag():effectperiod(2):effectmagnitude(0, 0, 5)
		end,
	}
end

local function create_menu_frame(pn, x, y)
	local frame= Def.ActorFrame{
		InitCommand= function(self)
			self:xy(x, y):playcommand("Hide")
			menu_frames[pn]= self
		end,
		ShowCommand= function(self)
			self:visible(true)
		end,
		HideCommand= function(self)
			self:visible(false)
		end,
		Def.Quad{
			InitCommand= function(self)
				self:setsize(menu_bg_width, menu_spacing * (#menu_choices + 1))
					:y(-menu_spacing):vertalign(top)
					:diffuse{0, 0, 0, .25}
					:playcommand("Hide")
			end,
		},
	}
	for i, choice in ipairs(menu_choices) do
		frame[#frame+1]= create_menu_item(pn, 0, (i-1)*menu_spacing, choice)
	end
	return frame
end

local function backout(screen)
	screen_gameplay:SetPrevScreenName(screen):begin_backing_out()
end

local function show_menu(pn)
	menu_frames[pn]:playcommand("Show")
	for i, item in ipairs(menu_items[pn]) do
		item:playcommand("LoseFocus")
	end
	current_menu_choice[pn]= 1
	menu_items[pn][current_menu_choice[pn]]:playcommand("GainFocus")
	menu_is_showing[pn]= true
end

local function close_menu(pn)
	menu_frames[pn]:playcommand("Hide")
	menu_is_showing[pn]= false
	local stay_paused= false
	for pn, showing in pairs(menu_is_showing) do
		if showing then
			stay_paused= true
		end
	end
	if not stay_paused then
		screen_gameplay:PauseGame(false)
	end
end

local choice_actions= {
	continue_playing= function(pn)
		close_menu(pn)
	end,
	restart_song= function(pn)
		backout("ScreenStageInformation")
	end,
	forfeit_song= function(pn)
		backout(SelectMusicOrCourse())
	end,
	skip_song= function(pn)
		screen_gameplay:PostScreenMessage("SM_NotesEnded", 0)
	end,
	forfeit_course= function(pn)
		backout(SelectMusicOrCourse())
	end,
}

local menu_actions= {
	Start= function(pn)
		local choice_name= menu_choices[current_menu_choice[pn]]
		if choice_actions[choice_name] then
			choice_actions[choice_name](pn)
		end
	end,
	Left= function(pn)
		if current_menu_choice[pn] > 1 then
			menu_items[pn][current_menu_choice[pn]]:playcommand("LoseFocus")
			current_menu_choice[pn]= current_menu_choice[pn] - 1
			menu_items[pn][current_menu_choice[pn]]:playcommand("GainFocus")
		end
	end,
	Right= function(pn)
		if current_menu_choice[pn] < #menu_choices then
			menu_items[pn][current_menu_choice[pn]]:playcommand("LoseFocus")
			current_menu_choice[pn]= current_menu_choice[pn] + 1
			menu_items[pn][current_menu_choice[pn]]:playcommand("GainFocus")
		end
	end,
}
menu_actions.Up= menu_actions.Left
menu_actions.Down= menu_actions.Right
menu_actions.MenuLeft= menu_actions.Left
menu_actions.MenuRight= menu_actions.Right
menu_actions.MenuUp= menu_actions.Up
menu_actions.MenuDown= menu_actions.Down

local function input(event)
	local pn= event.PlayerNumber
	if not enabled_players[pn] then return end
	local button= event.GameButton
	if not button then return end
	if event.type == "InputEventType_Release" then return end
	local is_paused= screen_gameplay:IsPaused()
	if is_paused then
		if menu_is_showing[pn] then
			if menu_actions[button] then
				menu_actions[button](pn)
				return true
			end
		else
			if pause_buttons[button] then
				show_menu(pn)
				return true
			end
		end
	else
		if event.type ~= "InputEventType_FirstPress" then return end
		if pause_buttons[button] then
			if pause_press_times[pn] and
			GetTimeSinceStart() - pause_press_times[pn] <= pause_double_tap_time then
				gameplay_pause_count= gameplay_pause_count + 1
				screen_gameplay:PauseGame(true)
				show_menu(pn)
			else
				pause_press_times[pn]= GetTimeSinceStart()
			end
		else
			pause_press_times[pn]= nil
		end
	end
end

local frame= Def.ActorFrame{
	OnCommand= function(self)
		screen_gameplay= SCREENMAN:GetTopScreen()
		screen_gameplay:AddInputCallback(input)
	end,
}

for i, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
	enabled_players[pn]= true
	frame[#frame+1]= create_menu_frame(pn, menu_x[pn], menu_y)
end

return frame
