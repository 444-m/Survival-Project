--!native
--!strict
--!optimize 2

return {
	yAxis = vector.create(0, 1, 0);
	xAxis = vector.create(1, 0, 0);
	zAxis = vector.create(0, 0, 1);
	flat = vector.create(1, 0, 1);

	reflect = function(v: vector, normal: vector): vector
		return v - 2 * normal * vector.dot(v, normal)
	end;

	projectOntoPlane = function(v: vector, planeNormal: vector): vector
		return v - planeNormal * vector.dot(v, planeNormal)
	end;

	closestPointOnSegment = function(point: vector, segA: vector, segB: vector): vector
		local segDir = segB - segA
		local t = vector.dot(point - segA, segDir) / vector.dot(segDir, segDir)
		t = math.clamp(t, 0, 1)
		return segA + t * segDir
	end;

	toNative = function(v: Vector3): vector
		return vector.create(v.X, v.Y, v.Z)
	end;

	perpendicular = function(v: vector): vector
		if math.abs(v.x) < math.abs(v.y) and math.abs(v.x) < math.abs(v.z) then
			return vector.create(0, -v.z, v.y)
		elseif math.abs(v.y) < math.abs(v.z) then
			return vector.create(-v.z, 0, v.x)
		else
			return vector.create(-v.y, v.x, 0)
		end
	end;

	getSlope = function(v: vector): number
		return math.atan2(v.y, vector.magnitude(vector.create(v.x, 0, v.z)))
	end;
}