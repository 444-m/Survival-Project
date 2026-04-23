local ReplicatedStorage = game:GetService("ReplicatedStorage")
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local ProjectileShared = {
	MapContainer = workspace:WaitForChild("objects");
	Map = workspace:WaitForChild("objects"):WaitForChild("map");
	Debris = workspace:WaitForChild("objects"):WaitForChild("debris");
	Revolver = {
		Speed = 900;
		MaxSpeed = 1300;
		MaxDistance = 1200;
		Acceleration = vector.zero; 
		BarrelName = "Barrel";
		MaxOriginOffset = 8;
		Damage = {
			Base = 45;
			HeadshotMultiplier = 2.2;
			Min = 18;
			FalloffStart = 70;
			FalloffEnd = 220;
		};
		Bullet = {
			Path = { "Assets", "Projectiles", "Revolver", "Bullet" };
			Attachment = "Attachment";
			Emit = "68";
			FaceOffset = CFrame.Angles(0, math.pi, 0);
		};
		OnHit = function(player: player, result, payload)
			print(player, result, payload)
		end;
		BulletHoleImage = "rbxassetid://18394854032";
		HitBulletHoleImage = "rbxassetid://10190412800"
	};
}

return table.freeze(ProjectileShared)
