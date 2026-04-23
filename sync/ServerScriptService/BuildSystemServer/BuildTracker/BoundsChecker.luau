local BoundsChecker = {};

function BoundsChecker.new()
	local self = setmetatable({
		ObjectBounds = {} :: {[Instance]: {CFrame: CFrame, Size: Vector3}},
	}, {__index = BoundsChecker});
	
	return self;
end

function BoundsChecker:AddObjectBounds(object: Object, size: Vector3, cframe: CFrame)
	self.ObjectBounds[object] = {
		CFrame = cframe,
		Size = size
	};
end

function BoundsChecker:RemoveObjectBounds(object: Instance)
	self.ObjectBounds[object] = nil;
end

function BoundsChecker:DoesBoundsOverlap(sizeA: Vector3, cframeA: CFrame, sizeB: Vector3, cframeB: CFrame)
	-- determine if each object is rotated 90/270 on Y
	local storedRotated = math.abs(cframeB.XVector.Z) > math.abs(cframeB.XVector.X)
	local incomingRotated = math.abs(cframeA.XVector.Z) > math.abs(cframeA.XVector.X)

	-- swap X/Z size if rotated 90/270, since the object's footprint flips
	local storedHalfX = (storedRotated and sizeB.Z or sizeB.X) / 2
	local storedHalfZ = (storedRotated and sizeB.X or sizeB.Z) / 2
	local incomingHalfX = (incomingRotated and sizeA.Z or sizeA.X) / 2
	local incomingHalfZ = (incomingRotated and sizeA.X or sizeA.Z) / 2

	local storedPos = cframeB.Position
	local incomingPos = cframeA.Position

	local overlapX = math.abs(storedPos.X - incomingPos.X) < (storedHalfX + incomingHalfX)
	local overlapZ = math.abs(storedPos.Z - incomingPos.Z) < (storedHalfZ + incomingHalfZ)

	if overlapX and overlapZ then
		return true
	else
		return false;
	end
end

function BoundsChecker:CheckBoundsOverlap(size: Vector3, cframe: CFrame)
	for object, bounds in self.ObjectBounds do
		local objectCFrame = bounds.CFrame
		local objectSize = bounds.Size

		if self:DoesBoundsOverlap(size, cframe, objectSize, objectCFrame) then
			return true, object
		end
	end

	return false, nil
end

return BoundsChecker;