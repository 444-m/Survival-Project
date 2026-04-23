--!strict
local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)
local LightingServer = require "@game/ServerStorage/Modules/Managers/LightingServer"

local TimeOfDayEnum = conch.args.enum_new({
	"Dawn", "Morning", "Noon", "Afternoon", "Dusk", "Evening", "Night", "Midnight",
}, "TimeOfDay", "a time of day phase")

conch.register("time_set", {
	description = "Sets the clock time (0-24).";
	permissions = {"time"};
	arguments = function()
		return conch.args.number("time", "clock time between 0 and 24")
	end;
	callback = function(Time: number)
		LightingServer.SetTime(Time)
	end;
})

conch.register("time_phase", {
	description = "Jumps to a named time of day phase.";
	permissions = {"time"};
	arguments = function()
		return TimeOfDayEnum
	end;
	callback = function(Phase)
		local Times = {
			Dawn = 5.5, Morning = 7.5, Noon = 12, Afternoon = 15,
			Dusk = 18, Evening = 20, Night = 22, Midnight = 0,
		}
		LightingServer.SetTime(Times[Phase])
	end;
})

conch.register("time_speed", {
	description = "Sets the day cycle speed multiplier. 1 = normal, 0 = frozen.";
	permissions = {"time"};
	arguments = function()
		return conch.args.number("speed", "speed multiplier")
	end;
	callback = function(Speed: number)
		LightingServer.SetSpeed(Speed)
	end;
})

conch.register("time_stop", {
	description = "Freezes the day/night cycle.";
	permissions = {"time"};
	arguments = function() return end;
	callback = function()
		LightingServer.SetSpeed(0)
	end;
})

conch.register("time_start", {
	description = "Resumes the day/night cycle at normal speed.";
	permissions = {"time"};
	arguments = function() return end;
	callback = function()
		LightingServer.SetSpeed(1)
	end;
})

return nil