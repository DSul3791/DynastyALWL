extends Node


const WORLD_DEFINITION_PATH: String = (
	"res://worlds/base_world/world_definition.tres"
)

const STRATIGRAPHY_PATH: String = (
	"res://worlds/base_world/base_stratigraphy.tres"
)

const PREVIEW_PATH: String = (
	"res://worlds/base_world/world_preview.png"
)

const SCOUR_PREVIEW_PATH: String = (
	"res://worlds/base_world/world_preview_scour.png"
)


const SurfaceFieldScript := preload(
	"res://src/builder/terrain/surface_height_field.gd"
)

const DepressionFieldScript := preload(
	"res://src/builder/hydrology/depression_resolved_height_field.gd"
)

const FlowMapScript := preload(
	"res://src/builder/hydrology/flow_direction_map.gd"
)

const AccumulationMapScript := preload(
	"res://src/builder/hydrology/flow_accumulation_map.gd"
)

const ChannelNetworkScript := preload(
	"res://src/builder/hydrology/channel_network.gd"
)

const FluvialSurfaceScript := preload(
	"res://src/builder/hydrology/fluvial_surface_height_field.gd"
)

const IncisionModelScript := preload(
	"res://src/builder/hydrology/channel_incision_model.gd"
)

const LakeBasinsScript := preload(
	"res://src/builder/hydrology/lake_basin_map.gd"
)

const LakeWaterScript := preload(
	"res://src/builder/hydrology/lake_water_model.gd"
)

const SurfaceWaterScript := preload(
	"res://src/builder/hydrology/surface_water_map.gd"
)

const OceanMaskScript := preload(
	"res://src/builder/hydrology/ocean_mask.gd"
)

const SurficialDepositsScript := preload(
	"res://src/builder/hydrology/surficial_deposit_map.gd"
)


# ==================================================
# DIAGNOSTIC CHANNEL COLORS
# ==================================================

const HEADWATER_COLOR := Color(
	0.08,
	0.20,
	0.42
)

const SMALL_STREAM_COLOR := Color(
	0.05,
	0.38,
	0.72
)

const STREAM_COLOR := Color(
	0.04,
	0.64,
	1.00
)

const MAJOR_RIVER_COLOR := Color(
	0.18,
	0.84,
	1.00
)


# ==================================================
# SCOUR COLORS
# ==================================================

const BEND_COLOR := Color(
	1.0,
	0.05,
	0.85
)

const CONFLUENCE_COLOR := Color(
	1.0,
	0.88,
	0.05
)

const POOL_COLOR := Color(
	0.0,
	0.95,
	1.0
)

const MIXED_COLOR := Color(
	1.0,
	1.0,
	1.0
)


func _ready() -> void:
	print("")
	print("======================================")
	print("WORLD PREVIEW")
	print("======================================")
	print("")

	var world_definition: WorldDefinition = (
		_load_world_definition()
	)

	if world_definition == null:
		return

	var stratigraphy: StratigraphyProfile = (
		_load_stratigraphy()
	)

	if stratigraphy == null:
		return


	# ==================================================
	# SURFACE
	# ==================================================

	print(
		"Building 8 m wrapped surface..."
	)

	var surface_field = (
		SurfaceFieldScript.new()
	)

	surface_field.setup(
		world_definition,
		stratigraphy,
		8.0
	)

	var expected_width: int = int(
		world_definition.size_x_meters
		/ 8
	)

	var expected_depth: int = int(
		world_definition.size_z_meters
		/ 8
	)

	if (
		surface_field.get_width()
			!= expected_width
		or surface_field.get_depth()
			!= expected_depth
	):
		push_error(
			(
				"Expected a %d x %d planning grid, "
				+ "but received %d x %d."
			)
			% [
				expected_width,
				expected_depth,
				surface_field.get_width(),
				surface_field.get_depth()
			]
		)

		return

	print(
		"Planning grid: ",
		surface_field.get_width(),
		" x ",
		surface_field.get_depth(),
		" @ ",
		surface_field.get_spacing_meters(),
		" m"
	)


	# ==================================================
	# INITIAL HYDROLOGY
	# ==================================================

	print(
		"Resolving initial depressions..."
	)

	var initial_resolved = (
		DepressionFieldScript.new()
	)

	initial_resolved.setup(
		surface_field
	)


	print(
		"Building initial flow..."
	)

	var initial_flow = (
		FlowMapScript.new()
	)

	initial_flow.setup(
		initial_resolved
	)


	print(
		"Building initial accumulation..."
	)

	var initial_accumulation = (
		AccumulationMapScript.new()
	)

	initial_accumulation.setup(
		initial_flow,
		initial_resolved
			.get_spacing_meters()
	)


	print(
		"Building initial channels..."
	)

	var initial_channels = (
		ChannelNetworkScript.new()
	)

	initial_channels.setup(
		initial_accumulation
	)


	# ==================================================
	# RIVER-CARVED TERRAIN
	# ==================================================

	print(
		"Carving river valleys..."
	)

	var fluvial_surface = (
		FluvialSurfaceScript.new()
	)

	fluvial_surface.setup(
		world_definition,
		stratigraphy,
		surface_field,
		initial_flow,
		initial_accumulation,
		initial_channels
	)


	# ==================================================
	# SCOUR DIAGNOSTIC MODEL
	#
	# This instance only reads the same signals used by
	# the actual incision model.
	#
	# It does not modify terrain.
	# ==================================================

	var scour_diagnostics = (
		IncisionModelScript.new()
	)

	scour_diagnostics.setup(
		world_definition,
		stratigraphy,
		surface_field,
		initial_flow,
		initial_accumulation,
		initial_channels
	)


	# ==================================================
	# FINAL HYDROLOGY
	# ==================================================

	print(
		"Resolving final depressions..."
	)

	var final_resolved = (
		DepressionFieldScript.new()
	)

	final_resolved.setup(
		fluvial_surface
	)


	print(
		"Building final flow..."
	)

	var final_flow = (
		FlowMapScript.new()
	)

	final_flow.setup(
		final_resolved
	)


	print(
		"Building final accumulation..."
	)

	var final_accumulation = (
		AccumulationMapScript.new()
	)

	final_accumulation.setup(
		final_flow,
		final_resolved
			.get_spacing_meters()
	)


	print(
		"Building final channels..."
	)

	var final_channels = (
		ChannelNetworkScript.new()
	)

	final_channels.setup(
		final_accumulation
	)


	# ==================================================
	# WATER
	# ==================================================

	print(
		"Detecting lake basins..."
	)

	var lake_basins = (
		LakeBasinsScript.new()
	)

	lake_basins.setup(
		final_resolved
	)


	print(
		"Building lake water model..."
	)

	var lake_water = (
		LakeWaterScript.new()
	)

	lake_water.setup(
		lake_basins,
		final_accumulation
	)


	print(
		"Building surface water..."
	)

	var ocean_mask = (
		OceanMaskScript.new()
	)

	ocean_mask.setup(
		world_definition,
		fluvial_surface
	)


	var surface_water = (
		SurfaceWaterScript.new()
	)

	surface_water.setup(
		fluvial_surface,
		final_channels,
		final_accumulation,
		lake_basins,
		lake_water,
		ocean_mask
	)


	# ==================================================
	# DEPOSITS
	# ==================================================

	print(
		"Building surficial deposits..."
	)

	var deposit_map = (
		SurficialDepositsScript.new()
	)

	deposit_map.setup(
		world_definition,
		fluvial_surface,
		surface_water,
		final_flow,
		final_accumulation,
		final_channels
	)

	if deposit_map == null:
		push_error(
			"Failed to construct surficial deposit map."
		)

		return


	# ==================================================
	# FINAL TERRAIN STATISTICS
	# ==================================================

	var width: int = (
		fluvial_surface.get_width()
	)

	var depth: int = (
		fluvial_surface.get_depth()
	)

	var minimum_height: float = INF
	var maximum_height: float = -INF

	var height_total: float = 0.0

	var sample_count: int = (
		width * depth
	)

	for grid_z in range(
		depth
	):
		for grid_x in range(
			width
		):
			var height: float = (
				fluvial_surface
					.get_height_at_grid(
						grid_x,
						grid_z
					)
			)

			minimum_height = minf(
				minimum_height,
				height
			)

			maximum_height = maxf(
				maximum_height,
				height
			)

			height_total += height


	var average_height: float = 0.0

	if sample_count > 0:
		average_height = (
			height_total
			/ float(sample_count)
		)


	print("")
	print(
		"Final terrain statistics:"
	)

	print(
		"  Minimum height: ",
		snappedf(
			minimum_height,
			0.1
		),
		" m"
	)

	print(
		"  Average height: ",
		snappedf(
			average_height,
			0.1
		),
		" m"
	)

	print(
		"  Maximum height: ",
		snappedf(
			maximum_height,
			0.1
		),
		" m"
	)


	# ==================================================
	# WRAP CHECK
	# ==================================================

	_print_wrap_statistics(
		fluvial_surface
	)


	# ==================================================
	# NORMAL PREVIEW
	# ==================================================

	print("")
	print(
		"Rendering preview PNG..."
	)

	var image: Image = Image.create(
		width,
		depth,
		false,
		Image.FORMAT_RGB8
	)

	for grid_z in range(
		depth
	):
		for grid_x in range(
			width
		):
			var height: float = (
				fluvial_surface
					.get_height_at_grid(
						grid_x,
						grid_z
					)
			)

			image.set_pixel(
				grid_x,
				grid_z,
				_get_height_color(
					height
				)
			)


	# ==================================================
	# CLEAN FRESHWATER / SCOUR PREVIEW
	# ==================================================

	var scour_image: Image = (
		_build_scour_diagnostic_image(
			fluvial_surface,
			initial_channels,
			scour_diagnostics,
			ocean_mask
		)
	)


	var absolute_scour_preview_path: String = (
		ProjectSettings.globalize_path(
			SCOUR_PREVIEW_PATH
		)
	)

	var scour_save_error: Error = (
		scour_image.save_png(
			absolute_scour_preview_path
		)
	)

	if scour_save_error != OK:
		push_error(
			(
				"Could not save scour diagnostic PNG. "
				+ "Error: %d"
			)
			% int(
				scour_save_error
			)
		)

		return


	var absolute_preview_path: String = (
		ProjectSettings.globalize_path(
			PREVIEW_PATH
		)
	)

	var save_error: Error = (
		image.save_png(
			absolute_preview_path
		)
	)

	if save_error != OK:
		push_error(
			(
				"Could not save preview PNG. "
				+ "Error: %d"
			)
			% int(
				save_error
			)
		)

		return


	print("")
	print("======================================")
	print("WORLD PREVIEW COMPLETE")
	print("======================================")
	print("")

	print(
		"Preview written to:"
	)

	print(
		absolute_preview_path
	)

	print("")

	print(
		"Freshwater/scour diagnostic written to:"
	)

	print(
		absolute_scour_preview_path
	)

	print("")

	print(
		"Channel legend:"
	)

	print(
		"  Dark blue   = headwater drainage"
	)

	print(
		"  Medium blue = small stream"
	)

	print(
		"  Bright blue = established stream"
	)

	print(
		"  Light blue  = major river"
	)

	print("")

	print(
		"Scour legend:"
	)

	print(
		"  Magenta = bend scour"
	)

	print(
		"  Yellow  = confluence scour"
	)

	print(
		"  Cyan    = pool/riffle"
	)

	print(
		"  White   = multiple scour mechanisms"
	)

	print("")

	print(
		"Ocean drainage is hidden."
	)

	print("")
	print(
		"No voxel regions were baked."
	)

	print("")


# ==================================================
# CLEAN FRESHWATER DIAGNOSTIC
# ==================================================

func _build_scour_diagnostic_image(
	terrain_field,
	channel_network,
	scour_diagnostics,
	ocean_mask
) -> Image:
	var width: int = (
		terrain_field.get_width()
	)

	var depth: int = (
		terrain_field.get_depth()
	)

	var image: Image = Image.create(
		width,
		depth,
		false,
		Image.FORMAT_RGB8
	)


	# ==================================================
	# DIMMED TERRAIN BACKGROUND
	# ==================================================

	for grid_z in range(
		depth
	):
		for grid_x in range(
			width
		):
			var height: float = (
				terrain_field
					.get_height_at_grid(
						grid_x,
						grid_z
					)
			)

			var terrain_color: Color = (
				_get_height_color(
					height
				)
			)

			image.set_pixel(
				grid_x,
				grid_z,
				terrain_color.lerp(
					Color(
						0.0,
						0.0,
						0.0
					),
					0.72
				)
			)


	# ==================================================
	# LAND-ONLY CHANNEL COUNTS
	# ==================================================

	var headwater_count: int = 0
	var small_stream_count: int = 0
	var stream_count: int = 0
	var major_count: int = 0


	# ==================================================
	# DRAW FRESHWATER CHANNEL NETWORK
	# ==================================================

	for grid_z in range(
		depth
	):
		for grid_x in range(
			width
		):
			if ocean_mask.is_ocean(
				grid_x,
				grid_z
			):
				continue

			var channel_class: int = (
				channel_network
					.get_channel_class(
						grid_x,
						grid_z
					)
			)

			if (
				channel_class
				== ChannelNetworkScript.CHANNEL_NONE
			):
				continue


			var channel_color: Color = (
				HEADWATER_COLOR
			)

			var channel_radius: int = 0


			match channel_class:
				ChannelNetworkScript.CHANNEL_HEADWATER:
					channel_color = (
						HEADWATER_COLOR
					)

					channel_radius = 0

					headwater_count += 1


				ChannelNetworkScript.CHANNEL_SMALL_STREAM:
					channel_color = (
						SMALL_STREAM_COLOR
					)

					channel_radius = 0

					small_stream_count += 1


				ChannelNetworkScript.CHANNEL_STREAM:
					channel_color = (
						STREAM_COLOR
					)

					channel_radius = 1

					stream_count += 1


				ChannelNetworkScript.CHANNEL_MAJOR:
					channel_color = (
						MAJOR_RIVER_COLOR
					)

					channel_radius = 1

					major_count += 1


			_draw_land_marker(
				image,
				ocean_mask,
				grid_x,
				grid_z,
				channel_radius,
				channel_color
			)


	# ==================================================
	# SCOUR MARKERS
	# ==================================================

	var bend_count: int = 0
	var confluence_count: int = 0
	var pool_count: int = 0
	var mixed_count: int = 0


	for grid_z in range(
		depth
	):
		for grid_x in range(
			width
		):
			if ocean_mask.is_ocean(
				grid_x,
				grid_z
			):
				continue

			if not channel_network.is_channel(
				grid_x,
				grid_z
			):
				continue


			var bend_strength: float = (
				scour_diagnostics
					._get_bend_strength(
						grid_x,
						grid_z
					)
			)

			var confluence_strength: float = (
				scour_diagnostics
					._get_confluence_strength(
						grid_x,
						grid_z
					)
			)

			var pool_strength: float = (
				scour_diagnostics
					._get_pool_sequence_strength(
						grid_x,
						grid_z
					)
			)


			# Keep the diagnostic conservative.
			#
			# We only draw reasonably strong examples so
			# the underlying stream hierarchy remains
			# visible.

			var bend_strong: bool = (
				bend_strength >= 0.55
			)

			var confluence_strong: bool = (
				confluence_strength >= 0.45
			)

			var pool_strong: bool = (
				pool_strength >= 0.55
			)


			var strong_count: int = 0

			if bend_strong:
				strong_count += 1

			if confluence_strong:
				strong_count += 1

			if pool_strong:
				strong_count += 1


			if strong_count == 0:
				continue


			var marker_color: Color = (
				POOL_COLOR
			)

			var marker_radius: int = 1


			if strong_count >= 2:
				marker_color = (
					MIXED_COLOR
				)

				mixed_count += 1


			elif confluence_strong:
				marker_color = (
					CONFLUENCE_COLOR
				)

				confluence_count += 1


			elif bend_strong:
				marker_color = (
					BEND_COLOR
				)

				bend_count += 1


			else:
				marker_color = (
					POOL_COLOR
				)

				pool_count += 1


			var strongest: float = maxf(
				bend_strength,
				maxf(
					confluence_strength,
					pool_strength
				)
			)


			if strongest >= 0.80:
				marker_radius = 2


			_draw_land_marker(
				image,
				ocean_mask,
				grid_x,
				grid_z,
				marker_radius,
				marker_color
			)


	# ==================================================
	# PRINT DIAGNOSTIC COUNTS
	# ==================================================

	print("")
	print(
		"Freshwater channel cells:"
	)

	print(
		"  Headwater:          ",
		headwater_count
	)

	print(
		"  Small stream:       ",
		small_stream_count
	)

	print(
		"  Established stream: ",
		stream_count
	)

	print(
		"  Major river:        ",
		major_count
	)


	print("")
	print(
		"Strong scour diagnostic cells:"
	)

	print(
		"  Bend-only:          ",
		bend_count
	)

	print(
		"  Confluence-only:    ",
		confluence_count
	)

	print(
		"  Pool/riffle-only:   ",
		pool_count
	)

	print(
		"  Mixed:              ",
		mixed_count
	)


	return image


# ==================================================
# LAND-ONLY MARKER
#
# This deliberately refuses to paint ocean cells.
#
# Larger streams can therefore be thickened for
# visibility without recreating those giant offshore
# streaks from the first diagnostic.
# ==================================================

func _draw_land_marker(
	image: Image,
	ocean_mask,
	center_x: int,
	center_z: int,
	radius: int,
	color: Color
) -> void:
	var width: int = (
		image.get_width()
	)

	var depth: int = (
		image.get_height()
	)


	for offset_z in range(
		-radius,
		radius + 1
	):
		for offset_x in range(
			-radius,
			radius + 1
		):
			var target_x: int = posmod(
				center_x
				+ offset_x,
				width
			)

			var target_z: int = posmod(
				center_z
				+ offset_z,
				depth
			)


			if ocean_mask.is_ocean(
				target_x,
				target_z
			):
				continue


			image.set_pixel(
				target_x,
				target_z,
				color
			)


# ==================================================
# WRAP STATISTICS
# ==================================================

func _print_wrap_statistics(
	terrain_field
) -> void:
	var width: int = (
		terrain_field.get_width()
	)

	var depth: int = (
		terrain_field.get_depth()
	)


	if (
		width < 2
		or depth < 2
	):
		return


	var x_total_difference: float = 0.0
	var x_max_difference: float = 0.0


	for grid_z in range(
		depth
	):
		var left_height: float = (
			terrain_field
				.get_height_at_grid(
					0,
					grid_z
				)
		)

		var right_height: float = (
			terrain_field
				.get_height_at_grid(
					width - 1,
					grid_z
				)
		)

		var difference: float = absf(
			left_height
			- right_height
		)

		x_total_difference += (
			difference
		)

		x_max_difference = maxf(
			x_max_difference,
			difference
		)


	var z_total_difference: float = 0.0
	var z_max_difference: float = 0.0


	for grid_x in range(
		width
	):
		var near_height: float = (
			terrain_field
				.get_height_at_grid(
					grid_x,
					0
				)
		)

		var far_height: float = (
			terrain_field
				.get_height_at_grid(
					grid_x,
					depth - 1
				)
		)

		var difference: float = absf(
			near_height
			- far_height
		)

		z_total_difference += (
			difference
		)

		z_max_difference = maxf(
			z_max_difference,
			difference
		)


	var x_average_difference: float = (
		x_total_difference
		/ float(depth)
	)

	var z_average_difference: float = (
		z_total_difference
		/ float(width)
	)


	print("")
	print(
		"Wrapped edge neighbor steps:"
	)

	print(
		"  X edge average: ",
		snappedf(
			x_average_difference,
			0.01
		),
		" m"
	)

	print(
		"  X edge maximum: ",
		snappedf(
			x_max_difference,
			0.01
		),
		" m"
	)

	print(
		"  Z edge average: ",
		snappedf(
			z_average_difference,
			0.01
		),
		" m"
	)

	print(
		"  Z edge maximum: ",
		snappedf(
			z_max_difference,
			0.01
		),
		" m"
	)


# ==================================================
# PREVIEW COLOR RAMP
# ==================================================

func _get_height_color(
	height: float
) -> Color:
	if height < -700.0:
		return _lerp_color(
			Color(
				0.02,
				0.04,
				0.12
			),
			Color(
				0.03,
				0.12,
				0.28
			),
			_inverse_lerp_clamped(
				-1000.0,
				-700.0,
				height
			)
		)


	if height < 0.0:
		return _lerp_color(
			Color(
				0.03,
				0.12,
				0.28
			),
			Color(
				0.08,
				0.35,
				0.58
			),
			_inverse_lerp_clamped(
				-700.0,
				0.0,
				height
			)
		)


	if height < 100.0:
		return _lerp_color(
			Color(
				0.16,
				0.32,
				0.12
			),
			Color(
				0.30,
				0.48,
				0.20
			),
			_inverse_lerp_clamped(
				0.0,
				100.0,
				height
			)
		)


	if height < 350.0:
		return _lerp_color(
			Color(
				0.30,
				0.48,
				0.20
			),
			Color(
				0.48,
				0.52,
				0.26
			),
			_inverse_lerp_clamped(
				100.0,
				350.0,
				height
			)
		)


	if height < 700.0:
		return _lerp_color(
			Color(
				0.48,
				0.52,
				0.26
			),
			Color(
				0.50,
				0.37,
				0.22
			),
			_inverse_lerp_clamped(
				350.0,
				700.0,
				height
			)
		)


	if height < 1200.0:
		return _lerp_color(
			Color(
				0.50,
				0.37,
				0.22
			),
			Color(
				0.44,
				0.38,
				0.32
			),
			_inverse_lerp_clamped(
				700.0,
				1200.0,
				height
			)
		)


	if height < 1600.0:
		return _lerp_color(
			Color(
				0.44,
				0.38,
				0.32
			),
			Color(
				0.66,
				0.66,
				0.64
			),
			_inverse_lerp_clamped(
				1200.0,
				1600.0,
				height
			)
		)


	return _lerp_color(
		Color(
			0.66,
			0.66,
			0.64
		),
		Color(
			0.96,
			0.97,
			0.98
		),
		_inverse_lerp_clamped(
			1600.0,
			2000.0,
			height
		)
	)


func _inverse_lerp_clamped(
	minimum: float,
	maximum: float,
	value: float
) -> float:
	if maximum <= minimum:
		return 0.0

	return clampf(
		(
			value
			- minimum
		)
		/ (
			maximum
			- minimum
		),
		0.0,
		1.0
	)


func _lerp_color(
	from_color: Color,
	to_color: Color,
	weight: float
) -> Color:
	return from_color.lerp(
		to_color,
		clampf(
			weight,
			0.0,
			1.0
		)
	)


# ==================================================
# RESOURCE LOADING
# ==================================================

func _load_world_definition() -> WorldDefinition:
	if not ResourceLoader.exists(
		WORLD_DEFINITION_PATH
	):
		push_error(
			"World definition not found: %s"
			% WORLD_DEFINITION_PATH
		)

		return null


	var resource: Resource = (
		ResourceLoader.load(
			WORLD_DEFINITION_PATH
		)
	)

	if resource == null:
		push_error(
			"Failed to load world definition."
		)

		return null


	if not resource is WorldDefinition:
		push_error(
			"Resource is not a WorldDefinition."
		)

		return null


	# Work on a copy so the shared cached resource keeps its master
	# seed, then configure tile (0, 0) so the preview uses the same
	# tile seed as the builder does for that tile.
	var world_definition: WorldDefinition = (
		resource.duplicate(true) as WorldDefinition
	)

	if world_definition == null:
		push_error("Could not duplicate the world definition.")

		return null

	world_definition.configure_island_tile(0, 0)

	if not world_definition.is_valid():
		push_error(
			"World definition contains invalid settings."
		)

		return null


	return world_definition


func _load_stratigraphy() -> StratigraphyProfile:
	if not ResourceLoader.exists(
		STRATIGRAPHY_PATH
	):
		push_error(
			"Stratigraphy profile not found: %s"
			% STRATIGRAPHY_PATH
		)

		return null


	var resource: Resource = (
		ResourceLoader.load(
			STRATIGRAPHY_PATH
		)
	)

	if resource == null:
		push_error(
			"Failed to load stratigraphy."
		)

		return null


	if not resource is StratigraphyProfile:
		push_error(
			"Resource is not a StratigraphyProfile."
		)

		return null


	var stratigraphy: StratigraphyProfile = (
		resource as StratigraphyProfile
	)

	if not stratigraphy.is_valid():
		push_error(
			"Stratigraphy contains invalid settings."
		)

		return null


	return stratigraphy
