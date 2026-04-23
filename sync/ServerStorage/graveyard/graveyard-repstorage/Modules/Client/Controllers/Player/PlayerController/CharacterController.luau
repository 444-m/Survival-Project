local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local CharacterController = {}
CharacterController.__index = CharacterController

local Packages = ReplicatedStorage.Packages
local SharedPackages = Packages.Shared

local ClientModules = ReplicatedStorage.Modules.Client
local ClientControllers = ClientModules.Controllers

local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local BetterAnimate = require(SharedPackages.BetterAnimate)
local CentralHeartbeat = require(ClientModules.CentralHeartbeat)

local InputHandler = require(ClientControllers.Movement.InputHandler)
local CameraController = require(ClientControllers.Camera.CameraController)

local MovementAnimations = ReplicatedStorage.Assets.Animations.Movement
local Animations = require(ClientModules.Animations)

local FootstepSounds = {
	Dirt = 178054124;
	Wood = 177940988;
	Concrete = 277067660;
	Grass = 4776173570;
	Metal = 4790537991;
	Sand = 4777003964;
	Fabric = 4776951843;
	Gravel = 4776998555;
	Marble = 4776962643;
}

local FootstepMaterialMap = {
	Mud = "Dirt";
	Pebble = "Dirt";
	Ground = "Dirt";

	Sand = "Sand";
	Snow = "Sand";
	Sandstone = "Sand";

	Rock = "Gravel";
	Basalt = "Gravel";
	Asphalt = "Gravel";
	Glacier = "Gravel";
	Slate = "Gravel";

	WoodPlanks = "Wood";
	LeafyGrass = "Grass";

	Ice = "Marble";
	Salt = "Marble";
	Marble = "Marble";
	Pavement = "Marble";
	Limestone = "Marble";

	Foil = "Metal";
	DiamondPlate = "Metal";
	CorrodedMetal = "Metal";
}

local MotionId = 1175918694

function CharacterController.new(Character: Model, MovementOptions: typeof(require(ClientControllers.Movement.configs)), AutoSetup: boolean?)
    local self = setmetatable({}, CharacterController)
    self.Character = Character
    self.Character:WaitForChild("HumanoidRootPart")

    local Animator = BetterAnimate.New(Character)
    Animator.FastConfig.AnimationPlayTransition = .35
    Animator.FastConfig.AnimationStopTransition = .35
    Animator.FastConfig.AlwaysUseCurrentTransition = true

    self.Animator = Animator
    self.MovementOptions = MovementOptions

    return self
end

function CharacterController:Setup()
    local Character = self.Character

    local Humanoid: Humanoid = Character:WaitForChild("Humanoid"); self.Humanoid = Humanoid
    local Head: BasePart = Character:WaitForChild("Head"); self.Head = Head
    local Animator = Humanoid:WaitForChild("Animator") :: Animator; self.PlayerAnimator = Animator

    Animations.init(Animator)
    self:SetupFootsteps()

    self.MovementInputHandler = InputHandler.new(Character, self.MovementOptions, self.Animator)

    self.CameraController = CameraController.new()

    self.CameraController:EnableCameraOffset()

    local DefaultAnimate = Character:FindFirstChild("Animate")
    if DefaultAnimate and (DefaultAnimate:IsA("LocalScript") or DefaultAnimate:IsA("Script")) then
        DefaultAnimate.Disabled = true
        DefaultAnimate:Destroy()
	end
	
	
	local CustomIdle
	local CustomWalk
	
	-- @all_clients --
	-- why only your UserId?
	if Player.UserId == MotionId or Player.UserId == 852643438 then
		local CustomIdleAnimation = Instance.new("Animation")
		CustomIdleAnimation.AnimationId = `rbxassetid://{103197732908250}`
		
		local CustomWalkAnimation = Instance.new("Animation")
		CustomWalkAnimation.AnimationId = `rbxassetid://{84891369286908}`
		
		CustomIdle, CustomWalk = CustomIdleAnimation, CustomWalkAnimation
	end

    local IdleAnimation = CustomIdle or findMovementAnimation("Idle")
    local WalkAnimation = CustomWalk or findMovementAnimation("Walk")
    local JumpAnimation = findMovementAnimation("Jump")
    local FallAnimation = findMovementAnimation("Fall")

    if IdleAnimation then
        self.Animator:SetClassPreset("Idle", { Idle = IdleAnimation })
    end

    if WalkAnimation then
        self.Animator:SetClassPreset("Walk", { Walk = WalkAnimation })
        self.Animator:SetClassPreset("Run", { Run = WalkAnimation })
    end

    if JumpAnimation then
        self.Animator:SetClassPreset("Jump", { Jump = JumpAnimation })
    end

    if FallAnimation then
        self.Animator:SetClassPreset("Fall", { Fall = FallAnimation })
    end

    self.Animator:SetInverseEnabled(true)

    local function runningState(Anim)
        local horizontalSpeed = 0
        if Character.PrimaryPart then
            local velocity = Character.PrimaryPart.AssemblyLinearVelocity
			horizontalSpeed = vector.magnitude((velocity * advents.vector.flat))
        end

        local walkSpeed = math.max(8, Humanoid.WalkSpeed)
		local walkAdjust = math.max(10, walkSpeed)
		local runAdjust = math.max(10, walkSpeed)
		
        Anim:SetClassAnimationSpeedAdjust("Walk", walkAdjust)
        Anim:SetClassAnimationSpeedAdjust("Run", runAdjust)

        local idleThreshold = math.max(1.2, (Humanoid.WalkSpeed * .12))
        local runThreshold = math.max(6, Humanoid.WalkSpeed + 2)

        if horizontalSpeed <= idleThreshold then
            Anim:PlayClassAnimation("Idle", .35)
        elseif horizontalSpeed <= runThreshold then
            Anim:PlayClassAnimation("Walk", .35)
        else
            Anim:PlayClassAnimation("Run", .35)
        end
    end

    self.Animator:SetStateFunction(Enum.HumanoidStateType.Running.Name, runningState)
    self.Animator:SetStateFunction(Enum.HumanoidStateType.RunningNoPhysics.Name, runningState)
    self.Animator:PlayClassAnimation("Idle", .35)

    local closeViewActive = false
    local closeViewEnter = 4.6
    local closeViewExit = 5.4

    local StepConnection = function(dt: number)
        self.Animator:Step(dt, Humanoid:GetState().Name)
        self:UpdateFootsteps()
        if self.CameraController:IsFirstPerson() then
            self.CameraController.yOffset = 0
            return
        end

        local cameraDistance = vector.magnitude(Head.Position - Camera.CFrame.Position)
        if closeViewActive then
            closeViewActive = cameraDistance < closeViewExit
        else
            closeViewActive = cameraDistance < closeViewEnter
        end
        self.CameraController.yOffset = closeViewActive and .67 or 0
    end

    self.StepConnection = StepConnection
    CentralHeartbeat:Bind(StepConnection)

end

function CharacterController:GetFootstepSoundId(material: Enum.Material): string
	local materialName = material.Name
	local soundId = FootstepSounds[materialName]

	if not soundId then
		local mapped = FootstepMaterialMap[materialName]
		if mapped then
			soundId = FootstepSounds[mapped]
		end
	end

	return "rbxassetid://" .. tostring(soundId or FootstepSounds.Concrete)
end

function CharacterController:SetupFootsteps()
	local rootPart = self.Character:WaitForChild("HumanoidRootPart")
	local existing = rootPart:FindFirstChild("MovementFootsteps")
	if existing and existing:IsA("Sound") then
		existing:Destroy()
	end

	local sound = Instance.new("Sound")
	sound.Name = "MovementFootsteps"
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 5
	sound.RollOffMaxDistance = 60
	sound.EmitterSize = 1.5
	sound.Volume = 0
	sound.PlaybackSpeed = 1
	sound.SoundId = self:GetFootstepSoundId(self.Humanoid and self.Humanoid.FloorMaterial or Enum.Material.Concrete)
	sound.Parent = rootPart

	self.MovementFootstepSound = sound
end

function CharacterController:GetMovementPhysics()
	local movementController = self:GetMovementController()
	if not movementController then
		return nil
	end

	return movementController.Physics
end

function CharacterController:GetMovementController()
	local inputHandler = self.MovementInputHandler
	if not inputHandler then
		return nil
	end

	return inputHandler.MovementController
end

function CharacterController:ApplyLevelUpBoost(_levelsGained: number?, boostStrength: number?, boostDuration: number?)
	if self.CameraController and self.CameraController.ApplyLevelBoost then
		self.CameraController:ApplyLevelBoost({
			LevelsGained = _levelsGained;
			BoostStrength = boostStrength;
			BoostDuration = boostDuration or self.MovementOptions.LevelUpBoostDuration or 0;
		})
	end

	local movementController = self:GetMovementController()
	local levelUpJumpBonus = math.max(0, math.floor((self.MovementOptions.LevelUpBoostJumpBonus or 0) + .5))
	if movementController and movementController.GrantLevelUpJumpBonus and levelUpJumpBonus > 0 then
		local humanoidState = self.Humanoid:GetState()
		if self.Humanoid.FloorMaterial ~= Enum.Material.Air
			and humanoidState ~= Enum.HumanoidStateType.Jumping
			and humanoidState ~= Enum.HumanoidStateType.Freefall
		then
			movementController:GrantLevelUpJumpBonus(levelUpJumpBonus)
		end
	end

	local physics = self:GetMovementPhysics()
	local rootPart = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = self.Humanoid
	if not physics or not rootPart or not rootPart:IsA("BasePart") or not humanoid then
		return
	end

	local duration = self.MovementOptions.LevelUpBoostDuration or 0
	if duration <= 0 then
		return
	end

	local strength = math.max(boostStrength or 1, 1)
	local horizontalVelocity = rootPart.AssemblyLinearVelocity * advents.vector.flat
	local boostDirection = horizontalVelocity
	if vector.magnitude(boostDirection) <= 2.5 then
		boostDirection = humanoid.MoveDirection * advents.vector.flat
	end
	if vector.magnitude(boostDirection) <= .001 then
		boostDirection = rootPart.CFrame.LookVector * advents.vector.flat
	end
	if vector.magnitude(boostDirection) > .001 then
		boostDirection = vector.normalize(boostDirection)
	else
		boostDirection = vector.zero
	end

	local immediateSpeed = self.MovementOptions.LevelUpBoostImmediateSpeed
		or math.max(((self.MovementOptions.SprintSpeed or 46) - (self.MovementOptions.DefaultSpeed or 16)) * .4, 8)
	local holdRatio = self.MovementOptions.LevelUpBoostImmediateHoldRatio or .35
	local decel = self.MovementOptions.LevelUpBoostImmediateDecel or 22
	local currentHorizSpeed = vector.magnitude(horizontalVelocity)
	local sprintSpeed = self.MovementOptions.SprintSpeed or 46
	local speedDeficitBonus = math.min(math.max(0, sprintSpeed - currentHorizSpeed) * .12, 4.5)
	local momentumCarryBonus = math.min(currentHorizSpeed * .07, 3.5)
	local scaledImmediateSpeed = (immediateSpeed + speedDeficitBonus + momentumCarryBonus) * (1 + ((strength - 1) * 1.08))
	local holdDuration = duration * holdRatio

	if physics.QueueManagedVelocity and vector.magnitude(boostDirection) > .001 then
		local handoffSpeed = math.min(4.5 + (currentHorizSpeed * .08), 8.5) * (0.9 + ((strength - 1) * .35))
		physics:QueueManagedVelocity({
			horizontal = boostDirection * handoffSpeed;
			horizontalMode = "add";
		})
	end

	physics:StartTemporarySpeedBoost(scaledImmediateSpeed, boostDirection, holdDuration, decel)
end

function CharacterController:GetCurrentFootstepMaterial(): (Enum.Material, boolean)
	local physics = self:GetMovementPhysics()
	if physics and physics:IsWallRunning() then
		local wallPart = physics.WallRunHitInstance
		if wallPart and wallPart:IsA("BasePart") then
			return wallPart.Material, true
		end

		return Enum.Material.Concrete, true
	end

	return self.Humanoid.FloorMaterial, false
end

function CharacterController:UpdateFootsteps()
	local sound = self.MovementFootstepSound
	local humanoid = self.Humanoid
	local rootPart = self.Character and self.Character:FindFirstChild("HumanoidRootPart") or nil
	if not sound or not humanoid or not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	if humanoid.Health <= 0 then
		if sound.Playing then
			sound:Stop()
		end
		return
	end

	local horizontalSpeed = vector.magnitude(rootPart.AssemblyLinearVelocity * advents.vector.flat)
	local state = humanoid:GetState()
	local footstepMaterial, wallRunning = self:GetCurrentFootstepMaterial()
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local shouldPlay = horizontalSpeed > 2
		and state ~= Enum.HumanoidStateType.Climbing
		and state ~= Enum.HumanoidStateType.Swimming
		and state ~= Enum.HumanoidStateType.FallingDown
		and (
			(
				grounded
				and humanoid.MoveDirection.Magnitude > .05
				and not humanoid.PlatformStand
				and state ~= Enum.HumanoidStateType.Freefall
				and state ~= Enum.HumanoidStateType.Jumping
			)
			or (wallRunning and horizontalSpeed > 10)
		)

	local desiredSoundId = self:GetFootstepSoundId(footstepMaterial)
	local soundIdChanged = sound.SoundId ~= desiredSoundId
	if soundIdChanged then
		sound.SoundId = desiredSoundId
	end

	local hipHeight = humanoid.HipHeight
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		hipHeight = 2.8
	end

	local scale = math.max(hipHeight / 3, .8)
	local defaultSpeed = math.max((self.MovementOptions.DefaultSpeed or 16) * scale, 1)
	local sprintSpeed = math.max((self.MovementOptions.SprintSpeed or 46) * scale, defaultSpeed + 1)
	local walkAlpha = math.max(horizontalSpeed / defaultSpeed, 0)
	local sprintAlpha = math.max((horizontalSpeed - defaultSpeed) / math.max(sprintSpeed - defaultSpeed, 1), 0)
	sound.Volume = math.clamp(((horizontalSpeed - 2) / 11) * scale, 0, .85)
	sound.PlaybackSpeed = .85 + (walkAlpha * .18) + (sprintAlpha * .18)

	if wallRunning then
		sound.Volume = math.clamp(math.max(sound.Volume, .22 + (sprintAlpha * .24)), 0, .95)
		sound.PlaybackSpeed += .08
	end

	if shouldPlay then
		if soundIdChanged and sound.Playing then
			sound:Stop()
		end

		if not sound.Playing then
			sound:Play()
		end
	elseif sound.Playing then
		sound:Stop()
	end
end

function normalize(name: string): string
    return string.lower((string.gsub(name, "[%s_%-]+", "")))
end

function findMovementAnimation(target: string): Animation?
    local targetNormalized = normalize(target)
    local partial: Animation? = nil
    for _, instance in next, MovementAnimations:GetDescendants() do
        if instance:IsA("Animation") then
            local normalizedName = normalize(instance.Name)
            if normalizedName == targetNormalized then
                return instance
            end
            if not partial and string.find(normalizedName, targetNormalized, 1, true) then
                partial = instance
            end
        end
    end
    return partial
end

function CharacterController:Destroy()
    if self.StepConnection then
        CentralHeartbeat:Unbind(self.StepConnection)
        self.StepConnection = nil
    end

	if self.MovementFootstepSound then
		self.MovementFootstepSound:Stop()
		self.MovementFootstepSound:Destroy()
		self.MovementFootstepSound = nil
	end

    if self.MovementInputHandler then
        self.MovementInputHandler:Destroy()
        self.MovementInputHandler = nil
    end

    if self.CameraController then
        self.CameraController:Destroy()
        self.CameraController = nil
    end

    setmetatable(self, nil)
end

return CharacterController
