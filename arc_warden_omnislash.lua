--[[
     ~ qLocalization
     ~ automatic localization wrapper for Lua menu interfaces

     ~ author: qfun (qfun_g9s)
]]

local qLocalization = (function()
	local lib = {}

	local a = function(...)
		return ...
	end

	local state = {
		lang = Menu.Find("SettingsHidden", "", "", "", "Main", "Language"),
		instances = {},
	}

	local setters = {
		ToolTip = "tooltip",
	}

	local helpers
	do
		helpers = {
			resolve = a(function(root, path)
				for key in path:gmatch("[^.]+") do
					if type(root) ~= "table" then
						return
					end

					root = root[key]
				end

				return root
			end),

			is_object = a(function(value)
				return type(value) == "table" or type(value) == "userdata"
			end),

			has_method = a(function(object, name)
				return helpers.is_object(object) and type(object[name]) == "function"
			end),

			is_menu_object = a(function(value)
				return helpers.has_method(value, "Name") and helpers.has_method(value, "Type")
			end),

			is_list = a(function(value)
				if type(value) ~= "table" or #value == 0 then
					return false
				end

				for i = 1, #value do
					if type(value[i]) ~= "string" then
						return false
					end
				end

				return true
			end),

			is_indexed_list = a(function(object)
				return helpers.has_method(object, "List") and not helpers.has_method(object, "ListEnabled")
			end),
		}
	end

	function lib.new(translations)
		local languages = {}

		for i, name in ipairs(state.lang and state.lang:List() or {}) do
			local code = name:match("%a+")

			if code and translations[code] then
				languages[i - 1] = code
			end
		end

		local localization = {
			translations = translations,
			languages = languages,
			objects = {},
		}

		local methods
		do
			methods = {
				get_language = a(function(language_index)
					if language_index == nil and state.lang then
						language_index = state.lang:Get()
					end

					return localization.languages[language_index] or "en"
				end),

				localize = a(function(path, language_index)
					if type(path) ~= "string" then
						return path
					end

					local language = methods.get_language(language_index)

					return helpers.resolve(localization.translations[language], path)
						or helpers.resolve(localization.translations.en, path)
						or path
				end),

				has = a(function(path)
					if type(path) ~= "string" then
						return false
					end

					return helpers.resolve(localization.translations.en, path) ~= nil
						or helpers.resolve(localization.translations[methods.get_language()], path) ~= nil
				end),

				localize_items = a(function(items, language_index)
					local result, localized = {}, false

					for i = 1, #items do
						local value = items[i]

						if methods.has(value) then
							result[i] = methods.localize(value, language_index)
							localized = true
						else
							result[i] = value
						end
					end

					return result, localized
				end),

				apply = a(function(object, kind, path, language_index)
					if kind == "label" then
						object:ForceLocalization(methods.localize(path, language_index))
					elseif kind == "tooltip" then
						object:ToolTip(methods.localize(path, language_index))
					elseif kind == "items" then
						local value = object:Get()

						object:Update((methods.localize_items(path, language_index)))
						object:Set(value)
					end
				end),

				track = a(function(object, kind, path, apply_now)
					local record = localization.objects[object]

					if record == nil then
						record = {}
						localization.objects[object] = record
					end

					record[kind] = path

					if apply_now then
						methods.apply(object, kind, path)
					end
				end),

				register = a(function(object, path)
					if not methods.has(path) or not helpers.has_method(object, "ForceLocalization") then
						return
					end

					methods.track(object, "label", path, true)
				end),

				update = a(function(language_index)
					for object, record in pairs(localization.objects) do
						for kind, path in pairs(record) do
							methods.apply(object, kind, path, language_index)
						end
					end
				end),

				wrap = a(function(target, bind_self)
					if not helpers.is_object(target) then
						return target
					end

					local proxy

					proxy = setmetatable({}, {
						__index = function(_, key)
							local member = target[key]

							if type(member) ~= "function" then
								return member
							end

							return function(...)
								local args = table.pack(...)

								if bind_self and args[1] == proxy then
									table.remove(args, 1)
									args.n = args.n - 1
								end

								if key == "Switch" and args.n < 2 then
									args[2] = false
									args.n = 2
								end

								local name_path, item_paths

								if setters[key] then
									if methods.has(args[1]) then
										methods.track(target, setters[key], args[1], false)

										args[1] = methods.localize(args[1])
									end
								else
									local name_index = bind_self and 1 or args.n

									if methods.has(args[name_index]) then
										name_path = args[name_index]
									end

									local items_index

									if key == "Combo" then
										items_index = 2
									elseif key == "Update" and helpers.is_indexed_list(target) then
										items_index = 1
									end

									if items_index ~= nil and helpers.is_list(args[items_index]) then
										local items, localized = methods.localize_items(args[items_index])

										if localized then
											item_paths = args[items_index]
											args[items_index] = items
										end
									end
								end

								local results

								if bind_self then
									results = table.pack(member(target, table.unpack(args, 1, args.n)))
								else
									results = table.pack(member(table.unpack(args, 1, args.n)))
								end

								for i = 1, results.n do
									local result = results[i]

									if helpers.is_menu_object(result) then
										if name_path then
											methods.register(result, name_path)
										end

										if item_paths then
											methods.track(result, "items", item_paths, false)
											item_paths = nil
										end

										results[i] = methods.wrap(result, true)
									end
								end

								if item_paths then
									methods.track(target, "items", item_paths, false)
								end

								return table.unpack(results, 1, results.n)
							end
						end,

						__newindex = function(_, key, value)
							target[key] = value
						end,
					})

					return proxy
				end),
			}
		end

		state.instances[methods] = true

		return {
			GetLanguage = methods.get_language,

			Get = methods.localize,
			Localize = methods.localize,

			Update = methods.update,
			Register = methods.register,

			Wrap = methods.wrap,

			WrapLibrary = function(library)
				return methods.wrap(library, false)
			end,
		}
	end

	if state.lang then
		state.lang:SetCallback(function(this)
			local language_index = this:Get()

			for methods in pairs(state.instances) do
				methods.update(language_index)
			end
		end, true)
	else
		Log.Write("[qLocalization] Language widget not found, using English fallback")
	end

	return lib
end)()

local localization = qLocalization.new({
	en = {
		aw_group_main = "Omnislash defense",
		aw_enable = "Auto Magnetic Field",
		aw_enable_tip = "Casts Magnetic Field just behind you when a nearby enemy Juggernaut starts Omnislash.\nA nearby Tempest Double casts a second field on the opposite side.",
		aw_gear_extra = "Options",
		aw_debug = "Debug log",
		aw_debug_tip = "Logs when the script activates, Magnetic Field becomes available, and an enemy Juggernaut starts Omnislash",
	},
	ru = {
		aw_group_main = "Защита от Омнислеша",
		aw_enable = "Автокупол",
		aw_enable_tip = "Ставит поле за вашей спиной при начале Омнислеша вражеским Джаггернаутом рядом.\nБлизкий Tempest Double ставит второе поле с противоположной стороны.",
		aw_gear_extra = "Настройки",
		aw_debug = "Отладка в лог",
		aw_debug_tip = "Пишет в лог включение скрипта, готовность купола и обнаружение начала Омнислеша",
	},
})

local UI = localization.WrapLibrary(Menu)

local ui = {}

do
	local hero_tab = UI.Find("Heroes", "Hero List", "Arc Warden")
	local page = hero_tab and hero_tab:Find("Main Settings")
	if not page then
		local tab = UI.Create("Scripts", "Scripts", "Arc Warden Omni")
		tab:Icon("\u{f013}")
		page = tab:Create("Settings")
	end

	local group = page:Create("aw_group_main", Enum.GroupSide.Right)
	ui.hero_enable = Menu.Find("Heroes", "Hero List", "Arc Warden", "Main Settings", "Hero Settings", "Enable")
	ui.enable = group:Switch("aw_enable", false, "\u{f011}")
	ui.enable:ToolTip("aw_enable_tip")
	local gear = ui.enable:Gear("aw_gear_extra")
	ui.debug = gear:Switch("aw_debug", true, "\u{f188}")
	ui.debug:ToolTip("aw_debug_tip")
end

local function active()
	return ui.enable:Get() and (not ui.hero_enable or ui.hero_enable:Get())
end

local function refresh_disabled()
	local on = active()
	ui.debug:Disabled(not on)
end

ui.enable:SetCallback(refresh_disabled, true)

local function log(text)
	if ui.debug:Get() then
		Log.Write("[Arc Warden Omni] " .. text)
	end
end

local state = {
	next_scan_time = 0,
	enemy_phases = {},
	omni_events = {},
	active = false,
	hero_valid = nil,
	field_ready = nil,
}

local script = {}

function script.OnUpdate()
	if not active() then
		if state.active then
			log("Automation paused")
		end
		state.active = false
		state.enemy_phases = {}
		state.omni_events = {}
		return
	end
	if not state.active then
		log("Automation active")
	end
	state.active = true

	local hero = Heroes.GetLocal()
	local hero_valid = hero ~= nil and Entity.IsAlive(hero)
		and NPC.GetUnitName(hero) == "npc_dota_hero_arc_warden"
	if hero_valid ~= state.hero_valid then
		state.hero_valid = hero_valid
		log(hero_valid and "Arc Warden detected" or "Waiting for Arc Warden")
	end
	if not hero_valid then
		state.enemy_phases = {}
		state.omni_events = {}
		return
	end

	local now = GameRules.GetGameTime()
	if now < state.next_scan_time then return end
	state.next_scan_time = now + 0.03

	local field = NPC.GetAbility(hero, "arc_warden_magnetic_field")
	local field_ready = field ~= nil
		and Ability.GetLevel(field) > 0
		and Ability.IsCastable(field, NPC.GetMana(hero))
	if field_ready ~= state.field_ready then
		state.field_ready = field_ready
		log(field_ready and "Magnetic Field is ready" or "Magnetic Field is unavailable")
	end

	local hero_team = Entity.GetTeamNum(hero)
	for _, enemy in ipairs(Heroes.GetAll()) do
		if enemy ~= hero and Entity.GetTeamNum(enemy) ~= hero_team
			and Entity.IsAlive(enemy)
			and NPC.GetUnitName(enemy) == "npc_dota_hero_juggernaut" then
			local omnislash = NPC.GetAbility(enemy, "juggernaut_omni_slash")
			if omnislash ~= nil then
				local casting = Ability.IsInAbilityPhase(omnislash)
				local enemy_index = Entity.GetIndex(enemy)
				local was_casting = state.enemy_phases[enemy_index] == true
				state.enemy_phases[enemy_index] = casting

				local cast_range = Ability.GetCastRange(omnislash)
				local slash_radius = Ability.GetLevelSpecialValueFor(omnislash, "omni_slash_radius")
				local danger_range = cast_range + slash_radius
				local event = state.omni_events[enemy_index]
				if casting and not was_casting then
					local in_range = danger_range > 0
						and NPC.IsEntityInRange(hero, enemy, danger_range)
					log(string.format(
						"Omnislash phase detected: field_ready=%s, danger_range=%.0f, in_range=%s",
						tostring(field_ready),
						danger_range,
						tostring(in_range)
					))
					if in_range then
						local window = Ability.GetCastPoint(omnislash)
							+ Ability.GetLevelSpecialValueFor(omnislash, "duration")
						event = {
							expires_at = now + window + 0.25,
							hero_cast = false,
							double_cast = false,
						}
						state.omni_events[enemy_index] = event
					end
				end

				if event ~= nil and now > event.expires_at then
					state.omni_events[enemy_index] = nil
					event = nil
				end

				if event ~= nil then
					local hero_position = Entity.GetAbsOrigin(hero)
					local forward = Entity.GetRotation(hero):GetForward():Normalized()

					if field_ready and not event.hero_cast then
						local field_radius = Ability.GetLevelSpecialValueFor(field, "radius")
						local back_position = hero_position - forward:Scaled(field_radius - 5)
						Ability.CastPosition(field, back_position)
						event.hero_cast = true
						log("Cast Magnetic Field behind Arc Warden")
					end

					if not event.double_cast then
						local owner = Entity.RecursiveGetOwner(hero)
						local double_found = false
						local double_issue = nil
						local double_details = nil
						for _, unit in ipairs(NPCs.GetAll()) do
							if unit ~= hero and Entity.IsAlive(unit)
								and Entity.GetTeamNum(unit) == hero_team
								and NPC.GetUnitName(unit) == "npc_dota_hero_arc_warden" then
								local unit_owner = Entity.RecursiveGetOwner(unit)
								local is_double = (owner ~= nil and unit_owner == owner)
									or Entity.RecursiveOwnedBy(unit, hero)
								if is_double then
									double_found = true
									local double_field = NPC.GetAbility(unit, "arc_warden_magnetic_field")
									if double_field == nil then
										double_issue = "missing_ability"
									elseif Ability.GetLevel(double_field) <= 0
										or not Ability.IsCastable(double_field, NPC.GetMana(unit)) then
										double_issue = "unavailable"
									else
										local double_radius = Ability.GetLevelSpecialValueFor(double_field, "radius")
										local front_position = hero_position + forward:Scaled(double_radius - 5)
										local double_cast_range = Ability.GetCastRange(double_field)
										local double_distance = Entity.GetAbsOrigin(unit):Distance2D(front_position)
										if double_cast_range > 0 and double_distance <= double_cast_range then
											Ability.CastPosition(double_field, front_position)
											event.double_cast = true
											event.double_status = "cast"
											log("Tempest Double cast Magnetic Field opposite the first field")
										else
											double_issue = "out_of_range"
											double_details = string.format(
												"distance=%.0f, range=%.0f",
												double_distance,
												double_cast_range
											)
										end
									end
									break
								end
							end
						end
						if not double_found then
							double_issue = "not_found"
						end
						if double_issue ~= nil and event.double_status ~= double_issue then
							event.double_status = double_issue
							if double_issue == "not_found" then
								log("Tempest Double not found for the local Arc Warden")
							elseif double_issue == "missing_ability" then
								log("Arc Warden clone found but Magnetic Field is missing")
							elseif double_issue == "unavailable" then
								log("Tempest Double Magnetic Field is unavailable")
							else
								log("Tempest Double field out of cast range: " .. double_details)
							end
						end
					end
				end
			end
		end
	end
end

return script
