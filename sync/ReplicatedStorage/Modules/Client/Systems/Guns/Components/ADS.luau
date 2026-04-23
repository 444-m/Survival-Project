local ADS = {}
ADS.__index = ADS

function ADS.new(cam, viewport)
	local self = setmetatable({}, ADS)
	self.Cam = cam
	self.Viewport = viewport
	self.BaseFov = cam and cam.Default_FoV or 70
	self.BaseThirdFov = (viewport and viewport.Configs and viewport.Configs.BaseFieldOfView) or self.BaseFov
	self.ToolConf = nil
	self.Active = false
	self.Humanoid = nil
	self._origWalk = nil
	self._origJump = nil
	self._usedJumpPower = nil
	self._thirdBase = nil
	return self
end

function ADS:SetEquipped(name, toolConf)
	self.ToolConf = toolConf
end

function ADS:SetHumanoid(h)
	self.Humanoid = h
end

local function pickFov(cam, tool, isFirst)
	local base = cam and cam.Default_FoV or 70
	if not tool then return base end
	if isFirst then
		return tool.AdsFov or (base - 10)
	end
	return tool.AdsThirdFov or tool.AdsFov or (base - 5)
end

local function applyMove(self, on)
	local h = self.Humanoid
	if not h then return end
	if on then
		if not self._origWalk then
			self._origWalk = h.WalkSpeed
		end
		if not self._origJump then
			if h.UseJumpPower ~= false then
				self._origJump = h.JumpPower
				self._usedJumpPower = true
			else
				self._origJump = h.JumpHeight
				self._usedJumpPower = false
			end
		end
		local slow = self.ToolConf and self.ToolConf.AdsWalkSpeed or (self._origWalk or 16) * 0.6
		h.WalkSpeed = slow
		if self._usedJumpPower then
			h.JumpPower = 0
		else
			h.JumpHeight = 0
		end
	else
		if self._origWalk then
			h.WalkSpeed = self._origWalk
		end
		if self._origJump then
			if self._usedJumpPower then
				h.JumpPower = self._origJump
			else
				h.JumpHeight = self._origJump
			end
		end
		self._origWalk = nil
		self._origJump = nil
		self._usedJumpPower = nil
	end
end

function ADS:Toggle(on)
	local tool = self.ToolConf
	if not tool or tool.CanAds == false then
		self.Active = false
		return
	end
	if self.Active == on then return end
	self.Active = on

	local cam = self.Cam
	local baseFov = cam and cam.Default_FoV or self.BaseFov
	local isFirst = cam and cam.IsInFirstPerson and cam:IsInFirstPerson() or false
	local adsFov = pickFov(cam, tool, isFirst)
	local adsThirdFov = pickFov(cam, tool, false)
	if cam then
		if on then
			cam:SetFov(adsFov)
		else
			cam:SetFov(baseFov)
		end
		if cam.Recoil and cam.Recoil.Aim then
			cam.Recoil:Aim(on)
		end
	end

	local view = self.Viewport
	if view then
		local cfg = nil
		if on and tool and tool.AdsViewportConfigs then
			cfg = tool.AdsViewportConfigs
		elseif tool and tool.ViewportConfigs then
			cfg = tool.ViewportConfigs
		end
		if cfg then
			for k, v in next, cfg do
				view:ChangeConfig(k, v)
			end
		end
		if on then
			self._thirdBase = self._thirdBase or (view.Configs and view.Configs.BaseFieldOfView) or self.BaseThirdFov or baseFov
			view:ChangeConfig("BaseFieldOfView", adsThirdFov)
		elseif self._thirdBase then
			view:ChangeConfig("BaseFieldOfView", self._thirdBase)
			self._thirdBase = nil
		end
	end

	applyMove(self, on)
end

return ADS
