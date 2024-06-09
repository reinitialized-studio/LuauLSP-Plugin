local ModuleRoot = { Silent = false }

local FormatString = require(script.Parent.FormatString)

local string_MessageOut = "[%s] %s"
local string_NameTag = script.Parent.Parent.Name

function ModuleRoot.print(Message: string, ...): ()
	if ModuleRoot.Silent ~= true then
		print(string_MessageOut:format(string_NameTag, FormatString(Message, ...)))
	end
end
function ModuleRoot.warn(Message: string, ...): ()
	if ModuleRoot.Silent ~= true then
		warn(string_MessageOut:format(string_NameTag, FormatString(Message, ...)))
	end
end
function ModuleRoot.error(Message: string, ...): ()
	error(string_MessageOut:format(string_NameTag, FormatString(Message, ...)), 2)
end
function ModuleRoot.assert<TCondition>(Condition: TCondition, Message: string, ...): ()
	if not Condition then
		error(string_MessageOut:format(string_NameTag, FormatString(Message, ...)), 2)
	end
end

return ModuleRoot
