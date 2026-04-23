export type Tool = {
	Image: string;
	MaxQuantity: number;
	CanAds: boolean;
	ActivateOnEquip: boolean?;
	Arms: {
		Left: boolean;
		Right: boolean;
	};
	ShiftLockOffset: Vector3;
	ForceShiftLock: boolean;
	ViewportConfigs: {
		XOffset: number;
		YOffset: number;
		ZOffset: number;
		Size: Vector3;
		FirstPersonFieldOfView: number;
		Rotation: {
			X: number;
			Y: number;
			Z: number;
		};
	};
	ReadyAt: number;
	Cooldown: number;
	Holdable: boolean;
	Recoil: {
		pattern: { Vector3 };
		patternReset: number;
		multiplier: number;
		visualScale: number;
		shakeScale: number;
		recovery: number;
		smoothing: number;
		kickSpeed: number;
		kickDamper: number;
	};
	Blur: {
		Size: number;
		Duration: number;
	};
	Stun: {
		duration: number;
		walkSpeed: number;
		jumpPower: number;
	};
	EquipRequirement: () -> boolean;
};

local Tools: { Tool } = {
	Axe = {
		Image = "rbxassetid://140559284995378";
		MaxQuantity = 1;
		CanAds = false;
		Arms = {
			Left = true;
			Right = true;
		};
		ShiftLockOffset = vector.create(1.9, 0.5, -0.9);
		ForceShiftLock = true;
		ViewportConfigs = {
			XOffset = .72;
			YOffset = .38;
			ZOffset = -.08;
			Size = vector.create(.65, 2.2, .65);
			FirstPersonFieldOfView = 82;
			Rotation = { X = 0; Y = 0; Z = 0 };
		};
		ReadyAt = .6;
		Cooldown = .93;
		Holdable = true; -- if u can hold mb1 to activate
		Recoil = {
			pattern = {
				{ x = 1.4, y = -6.2, z = 0.12 };
				{ x = -1.2, y = -5.4, z = -0.08 };
			};
			patternReset = 0.9;
			multiplier = 0.5;
			visualScale = 2.1;
			shakeScale = 1.3;
			recovery = .12;
			smoothing = .1;
			kickSpeed = 30;
			kickDamper = .48;
			maxX = 22;
			maxY = 30;
		};
		Blur = { Size = 2; Duration = .08 };
		Stun = {
			duration = .35;
			walkSpeed = 8;
			jumpPower = 1;
		};
	};

	Revolver = {
		Image = "rbxassetid://139213211758166";
		Ammo = 6;
		MaxAmmo = 6;
		Reserve = 24;
		CycleReloads = 3;
		MaxQuantity = 1;
		Arms = { -- arms the viewport will control
			Left = false;
			Right = true;
		};
		ShiftLockOffset = vector.create(2.25, 0.6, -0.95);
		ForceShiftLock = true;
		CameraOffset = vector.create(.05, -0.02, -0.12);
		ViewportConfigs = {
			XOffset = .30;
			YOffset = -.96;
			ZOffset = -.36;
			Size = vector.create(.65, 2.2, .65);
			FirstPersonFieldOfView = 75;
			Rotation = { X = -4; Y = 20; Z = 10 };
		};
		AdsViewportConfigs = {
			XOffset = -.06;
			YOffset = -.98;
			ZOffset = -.58;
			Size = vector.create(.58, 1.9, .58);
			FirstPersonFieldOfView = 60;
			Rotation = { X = -3.2; Y = 22; Z = 10 };
		};
		AdsFov = 55;
		AdsThirdFov = 62;
		ReadyAt = .73; -- during which .Activated for tool can fire (optional)
		Cooldown = .55;
		Holdable = false;
		Recoil = {
			pattern = {
				{ x = 1.8, y = 8.5, z = 0.15 };
				{ x = -1.4, y = 7.4, z = -0.08 };
				{ x = 1.6, y = 8.0, z = 0.12 };
				{ x = -1.2, y = 7.0, z = -0.05 };
			};
			patternReset = 0.7;
			multiplier = 2.9;
			adsMultiplier = 0.8;
			visualScale = 2.0;
			shakeScale = 1.5;
			recovery = .06;
			smoothing = .06;
			kickSpeed = 34;
			kickDamper = .45;
			maxX = 55;
			maxY = 80;
		};
		Blur = { Size = 4; Duration = .08 };
		Stun = {
			duration = .35;
			walkSpeed = 10;
			jumpPower = 28;
		};
	};

	Bandage = {
		Image = "rbxassetid://99076916829493";
		MaxQuantity = 5;
		CanAds = false;
		ActivateOnEquip = true;
		AutoUnequipOnUse = true;
		Arms = {
			Left = false;
			Right = false;
		};
		ForceShiftLock = false;
		ReadyAt = 0;
		Cooldown = 4.01;
		Holdable = false;
		Stun = {
			duration = 4.01;
			walkSpeed = 2;
			jumpPower = 0;
		};
	};
}

if game:GetService("RunService"):IsClient() then
	Tools.Bandage.EquipRequirement = function(data)
		local player: Player = data.Player
		print(player)
		
		if player then
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					if humanoid.Health >= humanoid.MaxHealth then
						return false
					end
				end
			end
		end
		
		return true
	end
end

return table.freeze(Tools)
