local States = {
	Idling = 0;
	DoubleJump = 0;
	Jumping = 0;
	Running = 1;
	Sliding = 2;
	WallHopping = 1.5; -- lwk forgot what this was
	Vaulting = 2.01;
	Mantling = 1.7;
	WallFlipping = 1.8;
	WallRunLeft = 1.8;
	WallRunRight = 1.8;
	WallJump = 1.8;
	Stunned = math.huge;
}

return table.freeze(States)
