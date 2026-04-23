--!strict

local Config = {}

Config.DayLength = 24 * 60
Config.StartTime = 5

Config.Phases = {

	Dawn = {
		Lighting = {
			ClockTime = 5.5,
			Ambient = Color3.fromRGB(70, 60, 75),
			OutdoorAmbient = Color3.fromRGB(95, 85, 100),
			Brightness = 1.2,
			ColorShift_Bottom = Color3.fromRGB(20, 12, 22),
			ColorShift_Top = Color3.fromRGB(200, 140, 110),
			EnvironmentDiffuseScale = .5,
			EnvironmentSpecularScale = .32,
			ExposureCompensation = -.45,
		},

		Fog = {
			FogColor = Color3.fromRGB(120, 115, 130),
			FogEnd = 500,
			FogStart = 0,
		},

		Atmosphere = {
			Density = 0.463,
			Offset = 0.938,
			Color = Color3.fromRGB(198, 204, 204),
			Decay = Color3.fromRGB(46, 59, 50),
			Glare = 0,
			Haze = 0.75,
		},

		Clouds = {
			Cover = .65,
			Density = .75,
			Color = Color3.fromRGB(180, 160, 170),
		},

		ColorCorrection = {
			Brightness = -.06,
			Contrast = .1,
			Saturation = -.15,
			TintColor = Color3.fromRGB(200, 180, 200),
		},

		SunRays = {
			Intensity = .15,
			Spread = .04,
		},
	},

	Morning = {
		Lighting = {
			ClockTime = 7.5,
			Ambient = Color3.fromRGB(100, 95, 105),
			OutdoorAmbient = Color3.fromRGB(130, 125, 135),
			Brightness = 1,
			ColorShift_Bottom = Color3.fromRGB(12, 10, 8),
			ColorShift_Top = Color3.fromRGB(230, 200, 150),
			EnvironmentDiffuseScale = .7,
			EnvironmentSpecularScale = .5,
			ExposureCompensation = -.1,
		},

		Fog = {
			FogColor = Color3.fromRGB(150, 150, 160),
			FogEnd = 600,
			FogStart = 0,
		},

		Atmosphere = {
			Density = 0.463,
			Offset = 0.938,
			Color = Color3.fromRGB(198, 204, 204),
			Decay = Color3.fromRGB(46, 59, 50),
			Glare = 0,
			Haze = 0.75,
		},

		Clouds = {
			Cover = .5,
			Density = .6,
			Color = Color3.fromRGB(210, 200, 210),
		},

		ColorCorrection = {
			Brightness = -.04,
			Contrast = .08,
			Saturation = -.08,
			TintColor = Color3.fromRGB(235, 225, 235),
		},

		SunRays = {
			Intensity = .15,
			Spread = .04,
		},
	},

	Noon = {
		Lighting = {
			ClockTime = 12,
			Ambient = Color3.fromRGB(120, 120, 130),
			OutdoorAmbient = Color3.fromRGB(150, 150, 160),
			Brightness = 1,
			ColorShift_Bottom = Color3.fromRGB(6, 6, 10),
			ColorShift_Top = Color3.fromRGB(200, 210, 230),
			EnvironmentDiffuseScale = .9,
			EnvironmentSpecularScale = .8,
			ExposureCompensation = .05,
		},

		Fog = {
			FogColor = Color3.fromRGB(150, 160, 170),
			FogEnd = 700,
			FogStart = 0,
		},

		Atmosphere = {
			Density = 0.463,
			Offset = 0.938,
			Color = Color3.fromRGB(198, 204, 204),
			Decay = Color3.fromRGB(46, 59, 50),
			Glare = 0,
			Haze = 0.75,
		},

		Clouds = {
			Cover = .4,
			Density = .5,
			Color = Color3.fromRGB(220, 225, 235),
		},

		ColorCorrection = {
			Brightness = -.02,
			Contrast = .08,
			Saturation = -.05,
			TintColor = Color3.fromRGB(220, 230, 245),
		},

		Bloom = {
			Intensity = .3,
			Size = 24,
			Threshold = 2,
		},

		SunRays = {
			Intensity = .15,
			Spread = .04,
		},
	},

	-- (same pattern applies to all other phases)

	Night = {
		Lighting = {
			ClockTime = 22,
			Ambient = Color3.fromRGB(1, 2, 3),
			OutdoorAmbient = Color3.fromRGB(2, 3, 5),
			Brightness = .006,
			ColorShift_Bottom = Color3.fromRGB(0, 0, 6),
			ColorShift_Top = Color3.fromRGB(10, 12, 20),
			EnvironmentDiffuseScale = .02,
			EnvironmentSpecularScale = .02,
			ExposureCompensation = -4.6,
		},

		Fog = {
			FogColor = Color3.fromRGB(8, 10, 18),
			FogEnd = 300,
			FogStart = 0,
		},

		Atmosphere = {
			Density = 0.463,
			Offset = 0.938,
			Color = Color3.fromRGB(198, 204, 204),
			Decay = Color3.fromRGB(46, 59, 50),
			Glare = 0,
			Haze = 0.75,
		},

		Clouds = {
			Cover = .85,
			Density = .9,
			Color = Color3.fromRGB(18, 20, 32),
		},

		ColorCorrection = {
			Brightness = -.36,
			Contrast = .28,
			Saturation = -.75,
			TintColor = Color3.fromRGB(60, 80, 130),
		},

		Bloom = {
			Intensity = .3,
			Size = 24,
			Threshold = 2,
		},

		SunRays = {
			Intensity = .15,
			Spread = .04,
		},
	},
}

return Config