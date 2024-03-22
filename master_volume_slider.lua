-- Settings

local settings = {
  volume = 100,
}


-- Mod info 

local modInfo = {
  name = "Master Volume Slider",
  author = "f4iTh",
  version = "1.0.0"
}


-- Local fields and variables

local defaultVolumes = {
  playerVolume = -1,
  followerVolume = -1,
  npcVolume = -1,
  musicVolume = -1,
  soundEffectVolume = -1,
  uiVolume = -1,
  voiceChatVolume = -1,
}

local volumeChanged = {
  player = { preMethod = false, postMethod = false },
  follower = { preMethod = false, postMethod = false },
  npc = { preMethod = false, postMethod = false },
  music = { preMethod = false, postMethod = false },
  soundEffect = { preMethod = false, postMethod = false },
  ui = { preMethod = false, postMethod = false, },
  voiceChat = { preMethod = false, postMethod = false }
}

local modUi = nil


-- Singletons

local snowWwiseManager = nil
local snowWwiseSituationVoiceManager = nil


-- Functions

local function save_settings()
  json.dump_file("MasterVolumeSlider.json", settings)
end

local function load_settings()
  local loadedSettings = json.load_file("MasterVolumeSlider.json")
  if loadedSettings then
    settings = loadedSettings
    log.info("[MasterVolumeSlider] successfully loaded MasterVolumeSlider.json")
  end
end

local function init_singletons()
  if not snowWwiseManager then
    snowWwiseManager = sdk.get_managed_singleton("snow.wwise.SnowWwiseManager")
  end

  if not snowWwiseSituationVoiceManager then
    snowWwiseSituationVoiceManager = sdk.get_managed_singleton("snow.wwise.WwiseSituationVoiceManager")
  end
end

local function update_situation_voice_controllers(context)
  if not snowWwiseSituationVoiceManager then
    return
  end

  local isVillageMethod = sdk.find_type_definition("snow.wwise.WwiseSituationVoiceManager"):get_method("isVillage")
  if not isVillageMethod then
    log.error("[MasterVolumeSlider] could not find isVillage method")
    return
  end

  local currentSituationVoiceControllers
  local currentSituationVoiceControllerListTypeDef
  local isInVillage = isVillageMethod:call(snowWwiseSituationVoiceManager)

  if isInVillage then
    currentSituationVoiceControllers = snowWwiseSituationVoiceManager:get_field("_LobbySituationVoiceControllers")
    currentSituationVoiceControllerListTypeDef = sdk.find_type_definition("System.Collections.Generic.List`1<snow.wwise.WwiseLobbySituationVoiceController>")
  else
    currentSituationVoiceControllers = snowWwiseSituationVoiceManager:get_field("_SituationVoiceControllers")
    currentSituationVoiceControllerListTypeDef = sdk.find_type_definition("System.Collections.Generic.List`1<snow.wwise.WwiseSituationVoiceController>")
  end

  if not currentSituationVoiceControllers then
    log.error("[MasterVolumeSlider] could not find situation voice controllers")
    return
  end

  if not currentSituationVoiceControllerListTypeDef then
    log.error("[MasterVolumeSlider] situation voice controller list type definition has not been found")
    return
  end

  local situationVoiceControllerListCountMethod = currentSituationVoiceControllerListTypeDef:get_method("get_Count")
  if not situationVoiceControllerListCountMethod then
    log.error("[MasterVolumeSlider] could not find get_Count method")
    return
  end

  local situationVoiceControllerListItemMethod = currentSituationVoiceControllerListTypeDef:get_method("get_Item")
  if not situationVoiceControllerListItemMethod then
    log.error("[MasterVolumeSlider] could not find get_Item method")
    return
  end

  local situationVoiceControllerListCount = situationVoiceControllerListCountMethod:call(currentSituationVoiceControllers)
  for i = 0, situationVoiceControllerListCount - 1, 1 do
    local voiceController = situationVoiceControllerListItemMethod:call(currentSituationVoiceControllers, i)
    if not voiceController then
      goto continue
    end

    local player = voiceController:get_field("_Player")
    if not player then
      log.error("[MasterVolumeSlider] could not get player from situation controller")
      goto continue
    end

    local playerMonitoredParams = player:get_field("_RefWwisePlayerMonitoredParameters")
    if not playerMonitoredParams then
      log.error("[MasterVolumeSlider] could not find player monitored params")
      goto continue
    end

    local isServant = playerMonitoredParams:get_field("_IsServant")
    if context == "reset" then
      if isServant then
        playerMonitoredParams:set_field("_OptionVolSV", defaultVolumes.followerVolume)
      else
        playerMonitoredParams:set_field("_OptionVol", defaultVolumes.playerVolume)
      end
    elseif context == "update" then
      if isServant then
        playerMonitoredParams:set_field("_OptionVolSV", defaultVolumes.followerVolume * (settings.volume / 100))
      else
        playerMonitoredParams:set_field("_OptionVol", defaultVolumes.playerVolume * (settings.volume / 100))
      end
    elseif context == "update_follower" then
      if isServant then
        playerMonitoredParams:set_field("_OptionVolSV", defaultVolumes.followerVolume * (settings.volume / 100))
      end
    elseif context == "update_player" then
      if not isServant then
        playerMonitoredParams:set_field("_OptionVol", defaultVolumes.playerVolume * (settings.volume / 100))
      end
    -- elseif context == "get" then
    --   if isServant then
    --     log.debug("[MasterVolumeSlider] servant volume: " .. playerMonitoredParams:get_field("_OptionVolSV"))
    --   else
    --     log.debug("[MasterVolumeSlider] player volume: " .. playerMonitoredParams:get_field("_OptionVol"))
    --   end
    else
      log.error("[MasterVolumeSlider] unknown updateType")
    end

    ::continue::
  end
end

local function get_default_volume()
  if snowWwiseManager then
    defaultVolumes.playerVolume = snowWwiseManager:get_field("_CurrentVolumePlayerVoice")
    defaultVolumes.followerVolume = snowWwiseManager:get_field("_CurrentVolumeServantVoice")
    defaultVolumes.npcVolume = snowWwiseManager:get_field("_CurrentVolumeNPCVoice")
    defaultVolumes.musicVolume = snowWwiseManager:get_field("_CurrentVolumeMusic")
    defaultVolumes.soundEffectVolume = snowWwiseManager:get_field("_CurrentVolumeSe")
    defaultVolumes.uiVolume = snowWwiseManager:get_field("_CurrentVolumeUI")
    defaultVolumes.voiceChatVolume = snowWwiseManager:get_field("_CurrentVolumeVoiceChat")
  end
end

local function reset_volume_to_default()
  if snowWwiseManager then
    snowWwiseManager:set_field("_CurrentVolumePlayerVoice", defaultVolumes.playerVolume)
    snowWwiseManager:set_field("_CurrentVolumeServantVoice", defaultVolumes.followerVolume)
    snowWwiseManager:set_field("_CurrentVolumeNPCVoice", defaultVolumes.npcVolume)
    snowWwiseManager:set_field("_CurrentVolumeMusic", defaultVolumes.musicVolume)
    snowWwiseManager:set_field("_CurrentVolumeSe", defaultVolumes.soundEffectVolume)
    snowWwiseManager:set_field("_CurrentVolumeUI", defaultVolumes.uiVolume)
    snowWwiseManager:set_field("_CurrentVolumeVoiceChat", defaultVolumes.voiceChatVolume)
    update_situation_voice_controllers("reset")
  end
end

local function update_volumes()
  if snowWwiseManager then
    snowWwiseManager:set_field("_CurrentVolumePlayerVoice", defaultVolumes.playerVolume * (settings.volume / 100))
    snowWwiseManager:set_field("_CurrentVolumeServantVoice", defaultVolumes.followerVolume * (settings.volume / 100))
    snowWwiseManager:set_field("_CurrentVolumeNPCVoice", defaultVolumes.npcVolume * (settings.volume / 100))
    snowWwiseManager:set_field("_CurrentVolumeMusic", defaultVolumes.musicVolume * (settings.volume / 100))
    snowWwiseManager:set_field("_CurrentVolumeSe", defaultVolumes.soundEffectVolume * (settings.volume / 100))
    snowWwiseManager:set_field("_CurrentVolumeUI", defaultVolumes.uiVolume * (settings.volume / 100))
    snowWwiseManager:set_field("_CurrentVolumeVoiceChat", defaultVolumes.voiceChatVolume * (settings.volume / 100))
    update_situation_voice_controllers("update")
  end
end

local function init()
  -- log.info("[MasterVolumeSlider] init called")
  init_singletons()
  get_default_volume()
  update_volumes()
end


-- Pre-method hooks

local function on_pre_change_player_volume(args)
  volumeChanged.player.preMethod = (sdk.to_int64(args[3]) & 1) == 1
end

local function on_pre_change_follower_volume(args)
  volumeChanged.follower.preMethod = (sdk.to_int64(args[3]) & 1) == 1
end

local function on_pre_change_npc_volume(args)
  volumeChanged.npc.preMethod = (sdk.to_int64(args[3]) & 1) == 1
end

local function on_pre_change_music_volume(args)
  volumeChanged.music.preMethod = (sdk.to_int64(args[3]) & 1) == 1
end

local function on_pre_change_soundeffect_volume(args)
  volumeChanged.soundEffect.preMethod = (sdk.to_int64(args[3]) & 1) == 1
end

local function on_pre_change_ui_volume(args)
  volumeChanged.ui.preMethod = (sdk.to_int64(args[3]) & 1) == 1
end

local function on_pre_change_voicechat_volume(args)
  volumeChanged.ui.preMethod = (sdk.to_int64(args[3]) & 1) == 1
end

local function on_pre_add_situation_voice_controller(args)
  local situationVoiceController = sdk.to_managed_object(args[3])
  if not situationVoiceController then
    log.error("[MasterVolumeSlider] could not get situation voice controller")
    return
  end

  local player = situationVoiceController:get_field("_Player")
  if not player then
    log.error("[MasterVolumeSlider] could not get player from situation controller")
    return
  end

  local playerMonitoredParams = player:get_field("_RefWwisePlayerMonitoredParameters")
  if not playerMonitoredParams then
    log.error("[MasterVolumeSlider] could not find player monitored params")
    return
  end

  local isServant = playerMonitoredParams:get_field("_IsServant")
  if isServant then
    playerMonitoredParams:set_field("_OptionVolSV", defaultVolumes.followerVolume * (settings.volume / 100))
  else
    playerMonitoredParams:set_field("_OptionVol", defaultVolumes.playerVolume * (settings.volume / 100))
  end
end

local function on_pre_add_lobby_situation_voice_controller(args)
  local situationVoiceController = sdk.to_managed_object(args[3])
  if not situationVoiceController then
    log.error("[MasterVolumeSlider] could not get situation voice controller")
    return
  end

  local player = situationVoiceController:get_field("_Player")
  if not player then
    log.error("[MasterVolumeSlider] could not get player from situation controller")
    return
  end

  local playerMonitoredParams = player:get_field("_RefWwisePlayerMonitoredParameters")
  if not playerMonitoredParams then
    log.error("[MasterVolumeSlider] could not find player monitored params")
    return
  end

  local isServant = playerMonitoredParams:get_field("_IsServant")
  if isServant then
    playerMonitoredParams:set_field("_OptionVolSV", defaultVolumes.followerVolume * (settings.volume / 100))
  else
    playerMonitoredParams:set_field("_OptionVol", defaultVolumes.playerVolume * (settings.volume / 100))
  end
end


-- Post-method hooks

local function on_post_change_player_volume(retVal)
  if snowWwiseManager then
    defaultVolumes.playerVolume = snowWwiseManager._CurrentVolumePlayerVoice
  end

  if volumeChanged.player.postMethod and not volumeChanged.player.preMethod then
    if snowWwiseManager then
      snowWwiseManager:set_field("_CurrentVolumePlayerVoice", defaultVolumes.playerVolume * (settings.volume / 100))
      update_situation_voice_controllers("update_player")
    end
  end

  volumeChanged.player.postMethod = volumeChanged.player.preMethod

  return retVal
end

local function on_post_change_follower_volume(retVal)
  if snowWwiseManager then
    defaultVolumes.followerVolume = snowWwiseManager._CurrentVolumeServantVoice

    if volumeChanged.follower.postMethod and not volumeChanged.follower.preMethod then
      snowWwiseManager:set_field("_CurrentVolumeServantVoice", defaultVolumes.followerVolume * (settings.volume / 100))
      update_situation_voice_controllers("update_follower")
    end
  end

  volumeChanged.follower.postMethod = volumeChanged.follower.preMethod

  return retVal
end

local function on_post_change_npc_volume(retVal)
  if snowWwiseManager then
    defaultVolumes.npcVolume = snowWwiseManager._CurrentVolumeNPCVoice

    if volumeChanged.npc.postMethod and not volumeChanged.npc.preMethod then
      snowWwiseManager:set_field("_CurrentVolumeNPCVoice", defaultVolumes.npcVolume * (settings.volume / 100))
    end
  end

  volumeChanged.npc.postMethod = volumeChanged.npc.preMethod

  return retVal
end

local function on_post_change_music_volume(retVal)
  if snowWwiseManager then
    defaultVolumes.musicVolume = snowWwiseManager._CurrentVolumeMusic

    if volumeChanged.music.postMethod and not volumeChanged.music.preMethod then
      snowWwiseManager:set_field("_CurrentVolumeMusic", defaultVolumes.musicVolume * (settings.volume / 100))
    end
  end

  volumeChanged.music.postMethod = volumeChanged.music.preMethod

  return retVal
end

local function on_post_change_soundeffect_volume(retVal)
  if snowWwiseManager then
    defaultVolumes.soundEffectVolume = snowWwiseManager._CurrentVolumeSe

    if volumeChanged.soundEffect.postMethod and not volumeChanged.soundEffect.preMethod then
      snowWwiseManager:set_field("_CurrentVolumeSe", defaultVolumes.soundEffectVolume * (settings.volume / 100))
    end
  end

  volumeChanged.soundEffect.postMethod = volumeChanged.soundEffect.preMethod

  return retVal
end

local function on_post_change_ui_volume(retVal)
  if snowWwiseManager then
    defaultVolumes.uiVolume = snowWwiseManager._CurrentVolumeUI

    if volumeChanged.ui.postMethod and not volumeChanged.ui.preMethod then
      snowWwiseManager:set_field("_CurrentVolumeUI", defaultVolumes.uiVolume * (settings.volume / 100))
    end
  end

  volumeChanged.ui.postMethod = volumeChanged.ui.preMethod

  return retVal
end

local function on_post_change_voicechat_volume(retVal)
  if snowWwiseManager then
    defaultVolumes.voiceChatVolume = snowWwiseManager._CurrentVolumeVoiceChat

    if volumeChanged.voiceChat.postMethod and not volumeChanged.voiceChat.preMethod then
      snowWwiseManager:set_field("_CurrentVolumeVoiceChat", defaultVolumes.voiceChatVolume * (settings.volume / 100))
    end
  end

  volumeChanged.voiceChat.postMethod = volumeChanged.voiceChat.preMethod

  return retVal
end

local function on_post_load_save_data(retVal)
  -- TODO: is this necessary?
  init_singletons()
  update_volumes()

  return retVal
end

local function on_post_snowwwwisemanager_start(retVal)
  -- TODO: is this necessary?
  init()

  return retVal
end

-- Mod initialization

load_settings()

sdk.hook(sdk.find_type_definition("snow.SnowSaveService"):get_method("loadSaveData"), nil, on_post_load_save_data)
sdk.hook(sdk.find_type_definition("snow.wwise.SnowWwiseManager"):get_method("set_ChangeingPlayerVoiceVolume"), on_pre_change_player_volume, on_post_change_player_volume)
sdk.hook(sdk.find_type_definition("snow.wwise.SnowWwiseManager"):get_method("set_ChangeingServantVolume"), on_pre_change_follower_volume, on_post_change_follower_volume)
sdk.hook(sdk.find_type_definition("snow.wwise.SnowWwiseManager"):get_method("set_ChangeingNPCVoiceVolume"), on_pre_change_npc_volume, on_post_change_npc_volume)
sdk.hook(sdk.find_type_definition("snow.wwise.SnowWwiseManager"):get_method("set_ChangeingBGMVolume"), on_pre_change_music_volume, on_post_change_music_volume)
sdk.hook(sdk.find_type_definition("snow.wwise.SnowWwiseManager"):get_method("set_ChangeingSEVolume"), on_pre_change_soundeffect_volume, on_post_change_soundeffect_volume)
sdk.hook(sdk.find_type_definition("snow.wwise.SnowWwiseManager"):get_method("set_ChangeingUIVolume"), on_pre_change_ui_volume, on_post_change_ui_volume)
sdk.hook(sdk.find_type_definition("snow.wwise.SnowWwiseManager"):get_method("set_ChangeingVoiceChatVolume"), on_pre_change_voicechat_volume, on_post_change_voicechat_volume)
sdk.hook(sdk.find_type_definition("snow.wwise.SnowWwiseManager"):get_method("start"), nil, on_post_snowwwwisemanager_start)
sdk.hook(sdk.find_type_definition("snow.wwise.WwiseSituationVoiceManager"):get_method("addSituationVoiceControllerList"), on_pre_add_situation_voice_controller, nil)
sdk.hook(sdk.find_type_definition("snow.wwise.WwiseSituationVoiceManager"):get_method("addLobbySituationVoiceControllerList"), on_pre_add_lobby_situation_voice_controller, nil)

init_singletons()
get_default_volume()
update_volumes()

-- Reframework menu

local function handle_volume_changed(changed)
  if not changed then
    return
  end

  update_volumes()
end

re.on_draw_ui(function()
  local settings_volume_changed = false

  if imgui.tree_node(modInfo.name) then
    settings_volume_changed, settings.volume = imgui.slider_int("Master Volume", settings.volume, 0, 100)
    handle_volume_changed(settings_volume_changed)

    -- if imgui.button("Print debug info") then
    --   log.debug("[MasterVolumeSlider] DEFAULT VALUES")
    --   log.debug("[MasterVolumeSlider] \tplayer: " .. defaultVolumes.playerVolume)
    --   log.debug("[MasterVolumeSlider] \tfollower: " .. defaultVolumes.followerVolume)
    --   log.debug("[MasterVolumeSlider] \tnpc: " .. defaultVolumes.npcVolume)
    --   log.debug("[MasterVolumeSlider] \tmusic: " .. defaultVolumes.musicVolume)
    --   log.debug("[MasterVolumeSlider] \tsound effect: " .. defaultVolumes.soundEffectVolume)
    --   log.debug("[MasterVolumeSlider] \tui: " .. defaultVolumes.uiVolume)
    --   log.debug("[MasterVolumeSlider] \tvoice chat: " .. defaultVolumes.voiceChatVolume)

    --   log.debug("[MasterVolumeSlider] CURRENT VALUES")
    --   if snowWwiseManager then
    --     log.debug("[MasterVolumeSlider] \tplayer: " .. snowWwiseManager._CurrentVolumePlayerVoice)
    --     log.debug("[MasterVolumeSlider] \tfollower: " .. snowWwiseManager._CurrentVolumeServantVoice)
    --     log.debug("[MasterVolumeSlider] \tnpc: " .. snowWwiseManager._CurrentVolumeNPCVoice)
    --     log.debug("[MasterVolumeSlider] \tmusic: " .. snowWwiseManager._CurrentVolumeMusic)
    --     log.debug("[MasterVolumeSlider] \tsound effect: " .. snowWwiseManager._CurrentVolumeSe)
    --     log.debug("[MasterVolumeSlider] \tui: " .. snowWwiseManager._CurrentVolumeUI)
    --     log.debug("[MasterVolumeSlider] \tvoice chat: " .. snowWwiseManager._CurrentVolumeVoiceChat)
    --   else
    --     log.debug("[MasterVolumeSlider] \tsnow.wwise.SnowWwiseManager has not been loaded")
    --   end

    --   log.debug("[MasterVolumeSlider] CONFIG VALUES")
    --   log.debug("[MasterVolumeSlider] \tvolume: " .. settings.volume)
    -- end

    imgui.tree_pop()
  end
end)

re.on_config_save(function()
  save_settings()
end)

re.on_script_reset(function()
  reset_volume_to_default()
end)


-- Custom In-Game Mod Menu integration

local function is_module_available(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.searchers or package.loaders) do
      local loader = searcher(name)
      if type(loader) == 'function' then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end

if is_module_available("ModOptionsMenu.ModMenuApi") then
  modUi = require("ModOptionsMenu.ModMenuApi")
end

if modUi then
  local settings_volume_changed = false

  modUi.OnMenu(modInfo.name, "Adjust master volume.", function()
    modUi.Header("Settings")
    settings_volume_changed, settings.volume = modUi.Slider("Master Volume", settings.volume, 0, 100, "Adjust master volume.")
    handle_volume_changed(settings_volume_changed)

    if settings_volume_changed then
      save_settings()
    end
  end)
end
