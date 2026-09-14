extends "res://Prototype/U13/U13ButcherLanePreview.gd"

func _configure_character() -> void:
	character_name = "Kopita"
	bundled_sheet_path = "res://Prototype/U13/Assets/KopitaSprite.png"
	source_dimensions = Vector2(1490, 1055)
	source_body_height = 225.0
	source_shader_path = ''
	has_redraw = false
	use_redraw = false
	extra_animation_labels = {2: "Inspect idle", 3: "Inspect attack"}
	frame_regions = {}
	frame_polygons = {}
	frame_regions[0] = [
		[Rect2(0, 0, 246, 233), Vector2(124.0, 230)],
		[Rect2(246, 0, 248, 233), Vector2(372.0, 230)],
		[Rect2(494, 0, 254, 233), Vector2(620.0, 230)],
		[Rect2(748, 0, 254, 233), Vector2(868.0, 230)],
		[Rect2(1002, 0, 254, 233), Vector2(1116.0, 230)],
		[Rect2(1256, 0, 234, 233), Vector2(1364.0, 230)],
	]
	frame_regions[1] = [
		[Rect2(0, 234, 253, 232), Vector2(124.0, 462)],
		[Rect2(253, 234, 257, 232), Vector2(372.0, 462)],
		[Rect2(510, 234, 249, 232), Vector2(620.0, 462)],
		[Rect2(759, 234, 249, 232), Vector2(868.0, 462)],
		[Rect2(1008, 234, 251, 232), Vector2(1116.0, 462)],
		[Rect2(1259, 234, 231, 232), Vector2(1364.0, 462)],
	]
	frame_regions[2] = [
		[Rect2(0, 467, 226, 233), Vector2(124.0, 696)],
		[Rect2(226, 467, 248, 233), Vector2(372.0, 696)],
		[Rect2(474, 467, 249, 233), Vector2(620.0, 696)],
		[Rect2(723, 467, 247, 233), Vector2(868.0, 696)],
		[Rect2(970, 467, 248, 233), Vector2(1116.0, 696)],
		[Rect2(1218, 467, 272, 233), Vector2(1364.0, 696)],
	]
	frame_regions[3] = [
		[Rect2(0, 701, 247, 200), Vector2(130, 897)],
		[Rect2(247, 701, 284, 200), Vector2(385, 897)],
		[Rect2(517, 701, 325, 200), Vector2(635, 897)],
		[Rect2(798, 701, 406, 200), Vector2(975, 897)],
		[Rect2(1204, 701, 286, 200), Vector2(1350, 897)],
	]
	frame_regions[4] = [
		[Rect2(0, 902, 226, 153), Vector2(124.0, 1048)],
		[Rect2(226, 902, 248, 153), Vector2(372.0, 1048)],
		[Rect2(474, 902, 248, 153), Vector2(620.0, 1048)],
		[Rect2(722, 902, 248, 153), Vector2(868.0, 1048)],
		[Rect2(970, 902, 270, 153), Vector2(1116.0, 1048)],
		[Rect2(1240, 902, 250, 153), Vector2(1364.0, 1048)],
	]
	frame_polygons = {
		3: {
			1: PackedVector2Array([
				Vector2(247, 701), Vector2(247, 901), Vector2(530, 901), Vector2(518, 897), Vector2(521, 896),
				Vector2(517, 895), Vector2(517, 893), Vector2(520, 892), Vector2(521, 891), Vector2(525, 890),
				Vector2(522, 889), Vector2(523, 888), Vector2(523, 887), Vector2(527, 885), Vector2(527, 884),
				Vector2(529, 883), Vector2(526, 882), Vector2(527, 881), Vector2(527, 880), Vector2(529, 879),
				Vector2(527, 878), Vector2(530, 877), Vector2(530, 871), Vector2(529, 870), Vector2(529, 869),
				Vector2(531, 867), Vector2(530, 866), Vector2(531, 865), Vector2(530, 864), Vector2(530, 863),
				Vector2(529, 862), Vector2(531, 861), Vector2(529, 860), Vector2(530, 859), Vector2(529, 858),
				Vector2(529, 857), Vector2(531, 856), Vector2(529, 855), Vector2(529, 848), Vector2(530, 847),
				Vector2(529, 846), Vector2(530, 845), Vector2(530, 842), Vector2(529, 841), Vector2(529, 827),
				Vector2(530, 826), Vector2(530, 806), Vector2(531, 805), Vector2(531, 804), Vector2(530, 803),
				Vector2(530, 794), Vector2(531, 793), Vector2(530, 792), Vector2(530, 701),
			]),
			2: PackedVector2Array([
				Vector2(530, 701), Vector2(530, 792), Vector2(531, 793), Vector2(530, 794), Vector2(530, 803),
				Vector2(531, 804), Vector2(531, 805), Vector2(530, 806), Vector2(530, 826), Vector2(529, 827),
				Vector2(529, 841), Vector2(530, 842), Vector2(530, 845), Vector2(529, 846), Vector2(530, 847),
				Vector2(529, 848), Vector2(529, 855), Vector2(531, 856), Vector2(529, 857), Vector2(529, 858),
				Vector2(530, 859), Vector2(529, 860), Vector2(531, 861), Vector2(529, 862), Vector2(530, 863),
				Vector2(530, 864), Vector2(531, 865), Vector2(530, 866), Vector2(531, 867), Vector2(529, 869),
				Vector2(529, 870), Vector2(530, 871), Vector2(530, 877), Vector2(527, 878), Vector2(529, 879),
				Vector2(527, 880), Vector2(527, 881), Vector2(526, 882), Vector2(529, 883), Vector2(527, 884),
				Vector2(527, 885), Vector2(523, 887), Vector2(523, 888), Vector2(522, 889), Vector2(525, 890),
				Vector2(521, 891), Vector2(520, 892), Vector2(517, 893), Vector2(517, 895), Vector2(521, 896),
				Vector2(518, 897), Vector2(530, 901), Vector2(820, 901), Vector2(820, 895), Vector2(819, 894),
				Vector2(820, 893), Vector2(820, 776), Vector2(818, 774), Vector2(818, 772), Vector2(819, 771),
				Vector2(819, 770), Vector2(817, 769), Vector2(816, 768), Vector2(818, 767), Vector2(816, 765),
				Vector2(812, 764), Vector2(806, 762), Vector2(805, 761), Vector2(801, 760), Vector2(801, 759),
				Vector2(800, 758), Vector2(800, 755), Vector2(798, 754), Vector2(799, 753), Vector2(799, 749),
				Vector2(798, 748), Vector2(798, 741), Vector2(799, 740), Vector2(799, 738), Vector2(798, 737),
				Vector2(799, 736), Vector2(799, 735), Vector2(798, 734), Vector2(842, 723), Vector2(842, 722),
				Vector2(841, 721), Vector2(842, 720), Vector2(841, 719), Vector2(842, 718), Vector2(839, 717),
				Vector2(840, 716), Vector2(837, 715), Vector2(821, 711), Vector2(820, 710), Vector2(820, 701),
			]),
			3: PackedVector2Array([
				Vector2(820, 701), Vector2(820, 710), Vector2(821, 711), Vector2(837, 715), Vector2(840, 716),
				Vector2(839, 717), Vector2(842, 718), Vector2(841, 719), Vector2(842, 720), Vector2(841, 721),
				Vector2(842, 722), Vector2(842, 723), Vector2(798, 734), Vector2(799, 735), Vector2(799, 736),
				Vector2(798, 737), Vector2(799, 738), Vector2(799, 740), Vector2(798, 741), Vector2(798, 748),
				Vector2(799, 749), Vector2(799, 753), Vector2(798, 754), Vector2(800, 755), Vector2(800, 758),
				Vector2(801, 759), Vector2(801, 760), Vector2(805, 761), Vector2(806, 762), Vector2(812, 764),
				Vector2(816, 765), Vector2(818, 767), Vector2(816, 768), Vector2(817, 769), Vector2(819, 770),
				Vector2(819, 771), Vector2(818, 772), Vector2(818, 774), Vector2(820, 776), Vector2(820, 893),
				Vector2(819, 894), Vector2(820, 895), Vector2(820, 901), Vector2(1204, 901), Vector2(1204, 701),
			]),
		},
	}
