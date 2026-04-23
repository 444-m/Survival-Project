--!strict

local minWalkSpeed = 3;
local baseWalkSpeed = 11;
local footStepRate = 1/2;

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = game.Players.LocalPlayer;
local char = script.Parent;
local humanoid = char:WaitForChild("Humanoid") :: Humanoid;
local FootstepModule = require(ReplicatedStorage.Modules.Client.misc.FootstepModule);
local footStepSoundGroup = FootstepModule:CreateSoundGroup(workspace, "FootstepSoundGroup") :: SoundGroup;

local lastFootStepTime = 0;
local walkConnection: RBXScriptConnection;
humanoid.Running:Connect(function(speed)
	if (speed > minWalkSpeed) then
		if walkConnection then
			return;
		end
		walkConnection = RunService.Heartbeat:Connect(function(delta)
			local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?;
			if humanoid.FloorMaterial and rootPart then
				local soundTable = FootstepModule:GetTableFromMaterial(humanoid.FloorMaterial)
				if not soundTable then return end;
				local randomSoundId = FootstepModule:GetRandomSound(soundTable);
				if not randomSoundId then return end;

				local currentTime = tick();
				if (currentTime - lastFootStepTime) < footStepRate * (baseWalkSpeed / humanoid.WalkSpeed) then
					return;
				end
				lastFootStepTime = currentTime;

				local newSound = Instance.new("Sound");
				newSound.RollOffMaxDistance = 45;
				newSound.RollOffMinDistance = 1;
				newSound.Volume = 0.2;
				newSound.RollOffMode = Enum.RollOffMode.InverseTapered;
				newSound.SoundId = randomSoundId;
				newSound.SoundGroup = footStepSoundGroup;
				newSound.Parent = rootPart;
				newSound.PlaybackSpeed = (humanoid.WalkSpeed / baseWalkSpeed);
				newSound:Play();
				newSound.Ended:Once(function()
					newSound:Destroy();
				end)
			end
		end)
	elseif walkConnection then
		walkConnection:Disconnect();
		walkConnection = nil;
	end
end)
