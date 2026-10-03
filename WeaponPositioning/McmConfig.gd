extends Node

var McmHelpers = load("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres")
var settings = load("res://WeaponPositioning/WeaponPositioningSettings.tres")

const MOD_ID = "WeaponPositioning"
const FRIENDLY_NAME = "Weapon Positioning"
const DESCRIPTION = "Adjust the weapon viewmodel field of view"

func _ready():
	if !McmHelpers:
		push_warning("[" + MOD_ID + "] Mod Configuration Menu not found, using default settings.")
		return

	var _mcmConfig = MCM_Config.new(MOD_ID, FRIENDLY_NAME, DESCRIPTION, UpdateConfigProperties, self)

	_mcmConfig.CreateBoolValue("Enabled", "Enabled", "Apply the custom viewmodel FOV.", true) \
		.setMenuPos(1) \
		.setOnValueChanged("OnValueChanged")

	_mcmConfig.CreateFloatValue("ViewmodelFOV", "Viewmodel FOV", "Field of view used to render the weapon while not aiming. Equal to your game FOV means vanilla. Aiming always uses the vanilla view.", 70.0) \
		.setMinRange(30.0) \
		.setMaxRange(120.0) \
		.setStep(1.0) \
		.setMenuPos(2) \
		.setOnValueChanged("OnValueChanged")

	_mcmConfig.CreateBoolValue("PreserveFovWhenAiming", "Keep viewmodel FOV when aiming", "Keep the weapon distance from the viewmodel FOV while aiming down sights (iron sights, red dots, canted). Magnified scopes and the vertical offset always use the vanilla view.", false) \
		.setMenuPos(3) \
		.setOnValueChanged("OnValueChanged")

	_mcmConfig.CreateFloatValue("VerticalOffset", "Vertical offset (cm)", "Moves the weapon up (positive) or down (negative) while not aiming. Aiming always uses the vanilla position.", 0.0) \
		.setMinRange(-10.0) \
		.setMaxRange(10.0) \
		.setStep(0.1) \
		.setMenuPos(4) \
		.setOnValueChanged("OnValueChanged")

	_mcmConfig.RegisterMod()

	# RegisterMod does not invoke the callback, so load the saved (profile aware) values once.
	UpdateConfigProperties(McmHelpers.GetModConfigFile(MOD_ID))

func UpdateConfigProperties(config: ConfigFile):
	settings.enabled = bool(GetMcmValue(config, "Bool", "Enabled", true))
	settings.viewmodel_fov = float(GetMcmValue(config, "Float", "ViewmodelFOV", 70.0))
	settings.preserve_fov_when_aiming = bool(GetMcmValue(config, "Bool", "PreserveFovWhenAiming", false))
	settings.vertical_offset_cm = float(GetMcmValue(config, "Float", "VerticalOffset", 0.0))

# Live preview while the user edits values in the menu
func OnValueChanged(valueId, newValue, _menu):
	match valueId:
		"Enabled":
			settings.enabled = bool(newValue)
		"ViewmodelFOV":
			settings.viewmodel_fov = float(newValue)
		"PreserveFovWhenAiming":
			settings.preserve_fov_when_aiming = bool(newValue)
		"VerticalOffset":
			settings.vertical_offset_cm = float(newValue)

func GetMcmValue(config: ConfigFile, section: String, key: String, default: Variant) -> Variant:
	var data = config.get_value(section, key, default)
	if data is Dictionary:
		return data.get("value", default)
	return data
