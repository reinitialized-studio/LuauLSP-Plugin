--!strict
local Plugin = plugin
assert(Plugin, "The LuauLSP Plugin must run under the Plugin context!")
if game:GetService("RunService"):IsRunning() then
	return
end

local HttpService = game:GetService("HttpService")
local StudioService = game:GetService("StudioService")

local Console = require(script.Libraries.Console)
local DeepClone = require(script.Libraries.DeepClone)
local TypeChecker = require(script.Libraries.TypeChecker)

local string_PluginSettings = script.Name .. "_Settings"
local string_PluginSettingsSource = script.Name .. "_SettingsSource"
local string_FullEndpoint = "%s/full"
local string_AssetId = "rbxassetid://%d"
local Asset_Connected = string_AssetId:format(11116536087)
local Asset_Disconnected = string_AssetId:format(11115506617)

local PluginToolbar = Plugin:CreateToolbar("Luau")
local PluginButton_ConnectionToggle = PluginToolbar:CreateButton("LuauConnectionToggle", "Toggle Connection to LuauLSP extension", Asset_Disconnected, "Toggle Connection")
local PluginButton_Settings = PluginToolbar:CreateButton("LuauSettings", "Open LuauLSP Settings", string_AssetId:format(13997395868), "Settings")

type ISettings = {
	Endpoint: string,
	StartOnStudioOpen: boolean,
	VisibleServices: { string },
}
type IEncodedInstance = {
	Name: string,
	ClassName: string,
	Children: { IEncodedInstance },
}
local StringArray = TypeChecker.Array(TypeChecker.BuiltInTypes.String)
local ISettings = TypeChecker.Interface({
	Endpoint = TypeChecker.BuiltInTypes.String,
	StartOnStudioOpen = TypeChecker.BuiltInTypes.Boolean,
	VisibleServices = StringArray,
})

local PluginSettings: ISettings
local PluginSettingsModule = script.Settings
local IsEditingPluginSettings = false

local WatchingDataModel = false
local WasConnected = false
local WatchingServices: { Instance } = {}
-- API
--- WatchingServices
local function IsDescendantOfWatchingService(PossibleDescendant: Instance): boolean
	for _, Service in WatchingServices do
		if PossibleDescendant:IsDescendantOf(Service) == true then
			return true
		end
	end

	return false
end
local function UpdateWatchingServices(): ()
	StringArray(PluginSettings.VisibleServices)

	for _, ServiceName in PluginSettings.VisibleServices do
		table.insert(WatchingServices, game:GetService(ServiceName))
	end
end
--- Settings
local function ValidateSettings(OptionalPluginSettings: ISettings?): boolean
	local Validating: ISettings
	if typeof(OptionalPluginSettings) ~= "nil" then
		Validating = OptionalPluginSettings
	else
		Validating = PluginSettings
	end

	-- Structure check
	if pcall(ISettings, Validating) == false then
		Console.warn("Settings does not match required formatting.")
		return false
	end
	-- Settings.Endpoint validation
	local EndpointValid = false
	if Validating.Endpoint:sub(1, 4) == "http" then
		-- Validate Start
		if Validating.Endpoint:sub(5, 9) == "s://" then
			EndpointValid = true
		elseif Validating.Endpoint:sub(5, 8) == "://" then
			EndpointValid = true
		end
		-- Validate End
		if EndpointValid ~= true and Validating.Endpoint:sub(#Validating.Endpoint) ~= "/" then
			EndpointValid = true
		end
	end
	if EndpointValid ~= true then
		Console.warn("Settings.Endpoint must start with either \"http://\" or \"https://\", but got %s instead. Please try again.", Validating.Endpoint:sub(1, 8))
		return false
	end

	return true
end
local function UpdatePluginSettings(): ()
	local CompiledFunction, CompileError = loadstring(PluginSettingsModule.Source)
	if typeof(CompiledFunction) == "nil" then
		Console.warn("CompileError when loading PluginSettings: %s", CompileError)
		return
	else
		local UpdatedSettings: ISettings
		local ExecuteSuccess: boolean, ExecuteError: string? = pcall(function()
			UpdatedSettings = CompiledFunction()
		end)
		if ExecuteSuccess ~= true then
			Console.warn("ExecuteError when loading PluginSettings: %s", ExecuteError)
		elseif typeof(UpdatedSettings) ~= "table" then
			Console.warn("PluginSettings is not expected type table, got %s instead", typeof(UpdatedSettings))
		else
			if ValidateSettings(UpdatedSettings) == true then
				PluginSettings = DeepClone(UpdatedSettings)
				Plugin:SetSetting(string_PluginSettings, PluginSettings)
				Plugin:SetSetting(string_PluginSettingsSource, PluginSettingsModule.Source)
				UpdateWatchingServices()

				Console.print("Updated PluginSettings successfully")
			end
		end
	end
end
local function LoadPluginSettings(): ()
	local SavedPluginSettings: ISettings? = Plugin:GetSetting(string_PluginSettings)
	if typeof(SavedPluginSettings) ~= "table" then
		UpdatePluginSettings()
	else
		local PluginSettingsSource: string? = Plugin:GetSetting(string_PluginSettingsSource)
		if typeof(PluginSettingsSource) == "string" then
			PluginSettingsModule.Source = PluginSettingsSource

			Console.print("Loaded PluginSettingsSource")
		end

		PluginSettings = SavedPluginSettings
		Console.print("Loaded PluginSettings")
	end
end

local function IsServiceVisible(Child: Instance): boolean
	return typeof(table.find(PluginSettings.VisibleServices, Child.Name)) == "number"
end
local function EncodeInstance(EncodingInstance: Instance): IEncodedInstance
	local EncodedInstance: IEncodedInstance = {
		Name = EncodingInstance.Name,
		ClassName = EncodingInstance.ClassName,
		Children = {},
	}
	for _, ChildInstance in EncodingInstance:GetChildren() do
		if IsServiceVisible(ChildInstance) == true then
			table.insert(EncodedInstance.Children, EncodeInstance(ChildInstance))
		end
	end

	return EncodedInstance
end
local function DisconnectFromExtension(): ()
	if WatchingDataModel == true then
		Console.print("Disconnecting from Extension at %s", PluginSettings.Endpoint)

		PluginButton_ConnectionToggle.Icon = Asset_Disconnected
		WatchingDataModel = false
	end
end
local function SendDataModelTree(): boolean
	local EncodedDataModel = EncodeInstance(game)
	local Success, Response = pcall(HttpService.RequestAsync, HttpService, {
		Method = "POST",
		Url = string_FullEndpoint:format(PluginSettings.Endpoint),
		Headers = {
			["Content-Type"] = "application/json",
		},
		Body = HttpService:JSONEncode({ tree = EncodedDataModel }),
		Compress = Enum.HttpCompression.Gzip,
	})

	if Success ~= true then
		Console.warn("Error connecting to LuauLSP Extension:\n%s", Response)

		DisconnectFromExtension()
	elseif Response.Success ~= true then
		Console.warn("Error when sending EncodedDataModel to LuauLSP Extension:\n%s", Response)

		DisconnectFromExtension()
	else
		WatchingDataModel = true
	end
	return WatchingDataModel
end
local function WatchDataModel(ChangingInstance: Instance): ()
	if WatchingDataModel ~= true then
		return
	end
	if ValidateSettings() ~= true then
		DisconnectFromExtension()
	end

	if IsDescendantOfWatchingService(ChangingInstance) == true then
		SendDataModelTree() -- TODO: delta encode
	end
end
local function ConnectToExtension(): ()
	if WatchingDataModel == false and ValidateSettings() == true then
		Console.print("Connecting to Extension at %s", PluginSettings.Endpoint)

		WatchingDataModel = true
		if SendDataModelTree() == true then
			Console.print("Connection established")
			PluginButton_ConnectionToggle.Icon = Asset_Connected
		end
	end
end
local function ToggleExtensionConnection()
	if WatchingDataModel == true then
		DisconnectFromExtension()
	else
		ConnectToExtension()
	end
end

--- Load Settings
LoadPluginSettings()
--- Establish Connections
PluginButton_ConnectionToggle.Click:Connect(ToggleExtensionConnection)
PluginButton_Settings.Click:Connect(function()
	IsEditingPluginSettings = true
	if WatchingDataModel == true then
		WasConnected = true
		DisconnectFromExtension()
	end

	Plugin:OpenScript(PluginSettingsModule)
end)
StudioService:GetPropertyChangedSignal("ActiveScript"):Connect(function()
	if StudioService.ActiveScript ~= PluginSettingsModule and IsEditingPluginSettings == true then
		UpdatePluginSettings()
		IsEditingPluginSettings = false

		if WasConnected == true then
			WasConnected = false
			ConnectToExtension()
		end
	end
end)
game.DescendantAdded:Connect(WatchDataModel)
game.DescendantRemoving:Connect(WatchDataModel)
--- Moving SettingsModule to somewhere in the DataModel
PluginSettingsModule.Parent = HttpService
--- Call ConnectToExtension if Settings.StartOnStudioOpen is true
if PluginSettings.StartOnStudioOpen == true then
	task.defer(ConnectToExtension)
end
