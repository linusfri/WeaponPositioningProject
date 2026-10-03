extends Node

# The game renders the weapon with the world camera (no separate viewmodel camera).
# A different viewmodel FOV is emulated by scaling the weapon rig root
# (Core/Camera/Manager) along the camera's view axis by
#   depthScale = tan(viewmodelFOV / 2) / tan(cameraFOV / 2)
# which projects the weapon exactly as a camera with viewmodelFOV would.
# Points on the screen center axis are unaffected, so sight alignment is kept.

const WEAPON_RIG_ROOT_PATH := "/root/Map/Core/Camera/Manager"
# Same easing and speed the game uses to move the weapon into/out of ADS
# (Handling.gd: position = lerp(position, target, delta * handlingSpeed)), so the
# mod's offset/scale fades in sync with the vanilla weapon movement.
const GAME_HANDLING_SPEED := 7.5
const CM_TO_METERS := 0.01

var gameData = preload("res://Resources/GameData.tres")
var settings = load("res://WeaponPositioning/WeaponPositioningSettings.tres")

var _weaponRigRoot: Node3D
# 0 = vanilla, 1 = fully modded. Each fades separately when aiming starts/stops,
# since the viewmodel FOV can optionally be kept while aiming but the height can't.
var _fovStrength := 0.0
var _heightStrength := 0.0
# Camera FOV of the scope zoom currently active or still zooming back out from.
# NO_SCOPE_ZOOM when the camera is not (or no longer) zoomed by a scope.
const NO_SCOPE_ZOOM := 180.0
var _scopeZoomFov := NO_SCOPE_ZOOM

# The bullet and wall-collision raycasts are children of the weapon rig, so the
# modified transform must only exist while rendering. Game logic and physics
# always see the vanilla transform; it is swapped in again at the end of _process.
func _ready() -> void:
	process_priority = 1000 # run after every game script
	get_tree().physics_frame.connect(_restore_vanilla_transform)
	get_tree().process_frame.connect(_restore_vanilla_transform)

func _restore_vanilla_transform() -> void:
	if is_instance_valid(_weaponRigRoot):
		_weaponRigRoot.scale = Vector3.ONE
		_weaponRigRoot.position = Vector3.ZERO

func _process(delta: float) -> void:
	if !is_instance_valid(_weaponRigRoot):
		_weaponRigRoot = get_node_or_null(WEAPON_RIG_ROOT_PATH) as Node3D
		_fovStrength = 0.0
		_heightStrength = 0.0
		if _weaponRigRoot == null:
			return

	var fadeWeight := minf(delta * GAME_HANDLING_SPEED, 1.0)
	_fovStrength = lerpf(_fovStrength, 1.0 if _should_apply_fov() else 0.0, fadeWeight)
	_heightStrength = lerpf(_heightStrength, 1.0 if _should_apply_height() else 0.0, fadeWeight)

	var camera := get_viewport().get_camera_3d()
	var liveCameraFov: float = camera.fov if camera else gameData.baseFOV

	# During a scope zoom (in or out), compute the depth scale against the base FOV
	# instead of the live one. The camera already zooms the weapon together with the
	# world; using the live FOV would cancel that zoom and make the scale explode.
	var depthReferenceFov: float = gameData.baseFOV if _is_scope_zoom_active(liveCameraFov) else liveCameraFov

	var depthScale := lerpf(1.0, _viewmodel_depth_scale(depthReferenceFov), _fovStrength)
	var verticalOffsetMeters: float = settings.vertical_offset_cm * CM_TO_METERS * _heightStrength

	_weaponRigRoot.scale = Vector3(1.0, 1.0, depthScale)
	_weaponRigRoot.position = Vector3(0.0, verticalOffsetMeters, 0.0)

# Shared conditions where the weapon must look vanilla.
func _is_blocked() -> bool:
	if !settings.enabled:
		return true
	# Grenade throw direction is derived from the rig's (scaled) basis.
	if gameData.grenade1 or gameData.grenade2:
		return true
	return false

func _is_aiming() -> bool:
	return gameData.isAiming or gameData.isCanted

func _should_apply_fov() -> bool:
	if _is_blocked():
		return false
	# Sights lie on the screen center axis, which the depth scale leaves untouched,
	# so keeping the FOV while aiming does not break sight alignment.
	if _is_aiming():
		# Non-PIP scopes zoom the camera heavily; fade to vanilla together with the
		# ADS weapon motion. PIP scopes magnify inside the lens, so the FOV can stay.
		if gameData.isScoped and !_should_keep_fov_in_pip_scope():
			return false
		return settings.preserve_fov_when_aiming
	return true

func _should_keep_fov_in_pip_scope() -> bool:
	return settings.preserve_fov_when_aiming and gameData.PIP

# True while the camera is zoomed by a scope or still zooming back out from one.
func _is_scope_zoom_active(liveCameraFov: float) -> bool:
	# PIP with preserved FOV: treat the camera zoom like any other FOV change, so the
	# depth scale follows the live FOV and the weapon does not zoom in with the camera.
	if gameData.isScoped and !_should_keep_fov_in_pip_scope():
		_scopeZoomFov = gameData.aimFOV
	if _scopeZoomFov >= gameData.baseFOV - 0.01:
		return false
	# Zoom-out finished: forget the scope so other FOV changes are not treated as scope zoom.
	if !gameData.isScoped and liveCameraFov >= gameData.baseFOV - 0.05:
		_scopeZoomFov = NO_SCOPE_ZOOM
		return false
	return true

func _should_apply_height() -> bool:
	# Moving the weapon up/down would move the sights off center, so always vanilla when aiming.
	return !_is_blocked() and !_is_aiming() and !gameData.isScoped

func _viewmodel_depth_scale(liveCameraFov: float) -> float:
	# Use the live camera FOV (it zooms slightly for some optics) so the weapon
	# always projects as if rendered with the configured viewmodel FOV.
	var cameraFovRadians := deg_to_rad(clampf(liveCameraFov, 1.0, 179.0))
	var viewmodelFovRadians := deg_to_rad(clampf(settings.viewmodel_fov, 1.0, 179.0))
	return tan(viewmodelFovRadians * 0.5) / tan(cameraFovRadians * 0.5)
