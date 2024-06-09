--!strict
--[[
	Core/Libraries/TypeChecker.luau
	A Luau-typed Runtime Typechecker with support for Roblox specific Types and Classes.
	https://code.reinitialized.studio/reinitialized.studio/reframe
]]
local ModuleRoot = {}
-- Dependencies
--- Roblox Services
--- Core
---- Assets
---- Constants
---- Libraries
---- Utilities
---- GlobalTypes
--- Script
-- Typings
--- Luau Typings
export type Check<T...> = (Value: unknown) -> T...
--- Runtime Typings
-- Constants
local string_ExpectedType = "Expected typeof %s, but got %s instead."
local string_ORCheckFailed = "Value did not match any of the provided parameters"
local string_ANDLeftCheckFailed = "And check failed for Left"
local string_ANDRightCheckFailed = "And check failed for Right"
local string_LiteralCheckFailed = "Literal check failed"
local string_NotGreaterOrEqual = "%d was not greater or equal to %d"
local string_NotLessThanOrEqual = "%d was not greater or equal to %d"
-- Variables
-- Private API
-- Public API
--- Types
---- BuiltInTypes
ModuleRoot.BuiltInTypes = {}
function ModuleRoot.BuiltInTypes.Boolean(Value: unknown): boolean
	assert(typeof(Value) == "boolean", string_ExpectedType:format("boolean", typeof(Value)))

	return Value
end
function ModuleRoot.BuiltInTypes.Buffer(Value: unknown): buffer
	assert(typeof(Value) == "buffer", string_ExpectedType:format("buffer", typeof(Value)))

	return Value
end
function ModuleRoot.BuiltInTypes.Function<A>(Value: unknown): A
	assert(typeof(Value) == "function", string_ExpectedType:format("function", typeof(Value)))

	return Value :: A
end
function ModuleRoot.BuiltInTypes.Nil(Value: unknown): nil
	assert(typeof(Value) == "nil", string_ExpectedType:format("nil", typeof(Value)))

	return Value
end
function ModuleRoot.BuiltInTypes.Number(Value: unknown): number
	assert(typeof(Value) == "number", string_ExpectedType:format("number", typeof(Value)))

	return Value
end
function ModuleRoot.BuiltInTypes.String(Value: unknown): string
	assert(typeof(Value) == "string", string_ExpectedType:format("string", typeof(Value)))

	return Value
end
function ModuleRoot.BuiltInTypes.Table<A>(Value: unknown): A
	assert(typeof(Value) == "table", string_ExpectedType:format("table", typeof(Value)))

	return Value :: A
end
function ModuleRoot.BuiltInTypes.Thread(Value: unknown): thread
	assert(typeof(Value) == "thread", string_ExpectedType:format("thread", typeof(Value)))

	return Value
end
function ModuleRoot.BuiltInTypes.Userdata<A>(Value: unknown): A
	assert(typeof(Value) == "userdata", string_ExpectedType:format("userdata", typeof(Value)))

	return Value :: A
end
function ModuleRoot.BuiltInTypes.Integer(Value: unknown): number
	ModuleRoot.BuiltInTypes.Number(Value)
	assert(Value :: number % 1 == 0, string_ExpectedType:format("Integer", typeof(Value)))

	return Value :: number
end
table.freeze(ModuleRoot.BuiltInTypes)
---- CustomTypes
ModuleRoot.CustomTypes = {}
function ModuleRoot.CustomTypes.Any(Value: unknown): any
	return Value
end
function ModuleRoot.CustomTypes.NotNil<A>(Value: A?): A
	assert(typeof(Value) ~= "nil", string_ExpectedType:format("to be not nil", "nil"))

	return Value
end
function ModuleRoot.CustomTypes.PositiveNumber(Value: unknown): number
	local Checking = ModuleRoot.BuiltInTypes.Number(Value)
	assert(Checking > 0, "Number must be greater than 0")

	return Checking
end
function ModuleRoot.CustomTypes.NegativeNumber(Value: unknown): number
	local Checking = ModuleRoot.BuiltInTypes.Number(Value)
	assert(Checking < 0, "Number must be less than 0")

	return Checking
end
ModuleRoot.CustomTypes.Undefined = newproxy()
--- Type Enforcement API
function ModuleRoot.Or<Types>(...: Check<Types>): Check<Types>
	local CheckArray = ModuleRoot.Array(ModuleRoot.BuiltInTypes.Function)({ ... })

	return function(Value: any)
		for _, Checker in CheckArray do
			if pcall(Checker, Value) == true then
				return Value
			end
		end

		error(string_ORCheckFailed, 2)
	end
end
function ModuleRoot.And<A, B>(Left: Check<A>, Right: Check<B>): Check<A & B>
	return function(Value: any)
		local LeftSuccess = pcall(Left, Value)

		if LeftSuccess ~= true then
			error(string_ANDLeftCheckFailed, 2)
		end

		local RightSuccess = pcall(Right, Value)

		if RightSuccess ~= true then
			error(string_ANDRightCheckFailed, 2)
		end

		return Value
	end
end
function ModuleRoot.Optional<A>(Check: Check<A>): Check<A?>
	return function(Value: any)
		if typeof(Value) == "nil" then
			return nil
		else
			return Check(Value)
		end
	end
end
function ModuleRoot.Literal<A>(Literal: A): Check<A>
	return function(Value: any)
		assert(Value == Literal, string_LiteralCheckFailed)

		return Value
	end
end
function ModuleRoot.Map<A, B>(Check1: Check<A>, Check2: Check<B>): Check<{ [A]: B }>
	return function(Value: any)
		ModuleRoot.BuiltInTypes.Table(Value)

		for Key, Value in Value do
			Check1(Key)
			Check2(Value)
		end
		return Value
	end
end
function ModuleRoot.Dictionary<A>(Check: Check<A>): Check<{ [A]: boolean }>
	return ModuleRoot.Map(Check, ModuleRoot.Literal(true))
end
function ModuleRoot.Array<A>(Check: Check<A>): Check<{ A }>
	ModuleRoot.BuiltInTypes.Function(Check)

	return ModuleRoot.Map(ModuleRoot.BuiltInTypes.Number, Check)
end
function ModuleRoot.Union<A>(...: Check<A>): Check<A>
	local CheckArray = ModuleRoot.Array(ModuleRoot.BuiltInTypes.Function)({ ... })

	return function(Value: any)
		for _, Checker in CheckArray do
			Checker(Value)
		end

		return Value
	end
end
function ModuleRoot.KeyOf<A>(KeysTable: { [any]: A }): Check<A>
	ModuleRoot.BuiltInTypes.Table(KeysTable)

	local Keys, Length = {}, 0

	for Key in KeysTable do
		Length += 1

		Keys[Length] = Key
	end

	return ModuleRoot.Literal(table.unpack(Keys, 1, Length))
end
function ModuleRoot.ValueOf<A>(ValuesTable: { [A]: any }): Check<A>
	ModuleRoot.BuiltInTypes.Table(ValuesTable)

	local Values, Length = {}, 0

	for _, Value in ValuesTable do
		Length += 1

		Values[Length] = Value
	end

	return ModuleRoot.Literal(table.unpack(Values, 1, Length))
end
function ModuleRoot.Interface<A, B>(Interface: { [A]: Check<B> }): Check<{ [A]: B }>
	ModuleRoot.BuiltInTypes.Table(Interface)

	local ExpectedKeys = 0
	for Key, _ in Interface do
		ExpectedKeys += 1
	end

	return function(Value: any)
		ModuleRoot.BuiltInTypes.Table(Value)

		local TotalKeys = 0
		for Key, CheckValue in Interface do
			TotalKeys += 1
			CheckValue(Value[Key])
		end
		assert(TotalKeys == ExpectedKeys, string.format("Interface expected %d keys, but Value provided %d", ExpectedKeys, TotalKeys))

		return Value
	end
end
function ModuleRoot.Tuples<A>(...: Check<A>): Check<A>
	local ChecksArray = { ... }

	return function(...: any)
		for Number, Check in ChecksArray do
			Check(select(Number, ...))
		end

		return ...
	end
end
function ModuleRoot.NumberMin(Minimal: number): Check<number>
	ModuleRoot.BuiltInTypes.Number(Minimal)

	return function(Value: any)
		ModuleRoot.BuiltInTypes.Number(Value)
		assert(Value >= Minimal, string.format(string_NotGreaterOrEqual, Value, Minimal))

		return Value
	end
end
function ModuleRoot.NumberMax(Maximum: number): Check<number>
	ModuleRoot.BuiltInTypes.Number(Maximum)

	return function(Value: any)
		ModuleRoot.BuiltInTypes.Number(Value)
		assert(Value <= Maximum, string.format(string_NotLessThanOrEqual, Value, Maximum))

		return Value
	end
end
function ModuleRoot.NumberConstrained(Minimal: number, Maximum: number): Check<number>
	ModuleRoot.BuiltInTypes.Number(Minimal)
	ModuleRoot.BuiltInTypes.Number(Maximum)

	return function(Value: any)
		ModuleRoot.BuiltInTypes.Number(Value)
		ModuleRoot.NumberMin(Minimal)(Value)
		ModuleRoot.NumberMax(Maximum)(Value)

		return Value
	end
end
function ModuleRoot.Check<A>(Check: Check<A>): Check<A>
	return function(Value: unknown)
		return Check(Value)
	end
end
-- Initialization
--- Return Public API
table.freeze(ModuleRoot)
return ModuleRoot
