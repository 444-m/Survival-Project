local Types = {}

export type Placeable = {
	Name: string,
	Template: Model,
	Health: number,
	BoundPart: BasePart;
}

export type Object = {
	Template: Placeable,
	Model: Model,
	Health: number,
	BoundPart: BasePart;
}

return Types
