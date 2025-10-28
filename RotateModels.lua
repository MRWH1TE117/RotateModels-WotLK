-- Rotate Models (WotLK 3.3.5a)
-- LMB drag = rotate, MouseWheel = fine rotate, MMB = reset

local ADDON_NAME = ...
local ROTATE_SPEED_DRAG  = 0.010  -- im wyższe, tym szybciej obraca przy przeciąganiu
local ROTATE_SPEED_WHEEL = 0.050  -- krok dla kółka

----------------------------------------------------------------------
-- Helpers: get/set facing (fallback dla starszych ramek)
----------------------------------------------------------------------
local function GetFacing(model)
  if model.GetFacing then
    return model:GetFacing()
  end
  return model.__rm_facing or 0
end

local function SetFacing(model, v)
  -- znormalizuj do [-pi, pi], żeby wartości nie rosły bez końca
  if v > math.pi or v < -math.pi then
    v = math.atan2(math.sin(v), math.cos(v))
  end
  if model.SetFacing then
    model:SetFacing(v)
  else
    model.__rm_facing = v
    if model.SetRotation then
      model:SetRotation(v) -- fallback, gdyby to był zwykły Model zamiast PlayerModel
    end
  end
  model.__rm_facing = v
end

----------------------------------------------------------------------
-- Podpinanie sterowania myszą do ramki modelu
----------------------------------------------------------------------
local function AttachRotateHandlers(model)
  if not model or model.__rm_attached then return end
  -- tylko dla ramek modelowych (mają SetFacing albo SetRotation)
  if not (model.SetFacing or model.SetRotation) then return end

  model:EnableMouse(true)
  model:EnableMouseWheel(true)

  -- LMB drag
  model:HookScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
      self.__rm_drag = true
      local x = GetCursorPosition()
      self.__rm_cursorX = x
      self.__rm_startFacing = GetFacing(self)
    elseif button == "MiddleButton" then
      -- reset obrotu
      SetFacing(self, 0)
      self.__rm_currentFacing = 0
    end
  end)

  model:HookScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
      self.__rm_drag = nil
    end
  end)

  model:HookScript("OnHide", function(self)
    self.__rm_drag = nil
  end)

  model:HookScript("OnUpdate", function(self, elapsed)
    if self.__rm_drag and self:IsVisible() then
      local x = GetCursorPosition()
      local dx = (x - (self.__rm_cursorX or x))
      self.__rm_cursorX = x
      -- ruch w prawo = obrót w prawo
      local f = (self.__rm_currentFacing or GetFacing(self)) + dx * ROTATE_SPEED_DRAG
      self.__rm_currentFacing = f
      SetFacing(self, f)
    end
  end)

  model:HookScript("OnMouseWheel", function(self, delta)
    local f = (self.__rm_currentFacing or GetFacing(self)) + (delta > 0 and ROTATE_SPEED_WHEEL or -ROTATE_SPEED_WHEEL)
    self.__rm_currentFacing = f
    SetFacing(self, f)
  end)

  -- Upewnij się, że mamy jakiś startowy facing (FIX: bez 'self' tutaj)
  if not model.__rm_currentFacing then
    model.__rm_currentFacing = GetFacing(model) or 0
  end

  model.__rm_attached = true
end

----------------------------------------------------------------------
-- Chowanie Blizz-owych przycisków rotacji
----------------------------------------------------------------------
local function HideAndLock(btn)
  if not btn then return end
  btn:Hide()
  btn:Disable()
  btn.Show = function() end -- zablokuj „wskrzeszanie”
end

local function HideRotateButtons()
  local names = {
    -- CharacterFrame
    "CharacterModelFrameRotateLeftButton",
    "CharacterModelFrameRotateRightButton",
    "CharacterRotateLeftButton",
    "CharacterRotateRightButton",

    -- DressUpFrame
    "DressUpModelRotateLeftButton",
    "DressUpModelRotateRightButton",
    "DressUpFrameRotateLeftButton",
    "DressUpFrameRotateRightButton",

    -- InspectFrame (właściwe na 3.3.5a)
    "InspectModelRotateLeftButton",
    "InspectModelRotateRightButton",

    -- inne spotykane warianty (na wszelki wypadek)
    "InspectModelFrameRotateLeftButton",
    "InspectModelFrameRotateRightButton",
    "InspectRotateLeftButton",
    "InspectRotateRightButton",
  }

  for _, n in ipairs(names) do
    HideAndLock(_G[n])
  end

  -- Fallback: przeskanuj dzieci znanych ramek i ukryj wszystko co wygląda na przycisk rotacji
  local function scanChildren(frame)
    if not frame or not frame.GetChildren then return end
    local kids = { frame:GetChildren() }
    for _, child in ipairs(kids) do
      if child and child.GetName and child:GetName() then
        local nm = child:GetName()
        if child.GetObjectType and child:GetObjectType() == "Button"
           and nm:find("Rotate") and (nm:find("Inspect") or nm:find("Character") or nm:find("DressUp")) then
          HideAndLock(child)
        end
      end
    end
  end

  scanChildren(_G.CharacterFrame)
  scanChildren(_G.DressUpFrame)
  scanChildren(_G.InspectFrame)
end

----------------------------------------------------------------------
-- Próba podpięcia do znanych ramek (jeśli już istnieją)
----------------------------------------------------------------------
local function TryAttachAll()
  -- CharacterFrame – standardowo w 3.3.5a: CharacterModelFrame
  if _G.CharacterModelFrame then
    AttachRotateHandlers(_G.CharacterModelFrame)
  end
  -- DressUpFrame – global: DressUpModel
  if _G.DressUpModel then
    AttachRotateHandlers(_G.DressUpModel)
  end
  -- InspectFrame – ładowany na żądanie (Blizzard_InspectUI), ale jeśli już jest:
  if _G.InspectModelFrame then
    AttachRotateHandlers(_G.InspectModelFrame)
  end

  HideRotateButtons()
end

----------------------------------------------------------------------
-- Eventy
----------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED") -- dla Blizzard_InspectUI

f:SetScript("OnEvent", function(_, event, addon)
  if event == "PLAYER_LOGIN" then
    -- Podepnij od razu, jeśli ramki już istnieją
    TryAttachAll()

    -- Hooki OnShow: gdy ramka pojawi się później
    if _G.CharacterFrame then
      _G.CharacterFrame:HookScript("OnShow", function()
        if _G.CharacterModelFrame then
          AttachRotateHandlers(_G.CharacterModelFrame)
        end
        HideRotateButtons()
      end)
    end

    if _G.DressUpFrame then
      _G.DressUpFrame:HookScript("OnShow", function()
        if _G.DressUpModel then
          AttachRotateHandlers(_G.DressUpModel)
        end
        HideRotateButtons()
      end)
    end

    if _G.InspectFrame then
      _G.InspectFrame:HookScript("OnShow", function()
        if _G.InspectModelFrame then
          AttachRotateHandlers(_G.InspectModelFrame)
        end
        HideRotateButtons()
      end)
    end

  elseif event == "ADDON_LOADED" and addon == "Blizzard_InspectUI" then
    -- Inspect UI właśnie się załadował – podepnij model i schowaj strzałki
    if _G.InspectModelFrame then
      AttachRotateHandlers(_G.InspectModelFrame)
    end
    if _G.InspectFrame then
      _G.InspectFrame:HookScript("OnShow", function()
        if _G.InspectModelFrame then
          AttachRotateHandlers(_G.InspectModelFrame)
        end
        HideRotateButtons()
      end)
    end
    HideRotateButtons()
  end
end)
