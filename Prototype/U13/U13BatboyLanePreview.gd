extends "res://Prototype/U13/U13ButcherLanePreview.gd"

func _configure_character() -> void:
	character_name = "Batboy"
	bundled_sheet_path = "res://Prototype/U13/Assets/BatboySprite.png"
	source_dimensions = Vector2(1374, 1145)
	source_body_height = 160.0
	source_shader_path = ""
	has_redraw = false
	use_redraw = false
	extra_animation_labels = {2: "Inspect idle", 3: "Inspect attack"}
	frame_regions = {}
	frame_polygons = {}
	var tops := [60, 260, 475, 658, 930]
	var bottoms := [235, 445, 653, 910, 1110]
	var grounds := [225, 431, 643, 895, 1090]
	for row in range(5):
		var poses: Array = []
		for column in range(6):
			var left := column * 229
			var right := (column + 1) * 229
			poses.append([Rect2(left, tops[row], right - left, bottoms[row] - tops[row]),
				Vector2(column * 229 + 115, grounds[row])])
		frame_regions[row] = poses

	# Follow the inter-frame gaps where wings, roots, and effects widen.
	frame_regions[0][0][0] = Rect2(0, 60, 228, 175)
	frame_regions[0][1][0] = Rect2(228, 60, 219, 175)
	frame_regions[0][2][0] = Rect2(447, 60, 230, 175)
	frame_regions[0][3][0] = Rect2(677, 60, 229, 175)
	frame_regions[0][4][0] = Rect2(906, 60, 223, 175)
	frame_regions[0][5][0] = Rect2(1129, 60, 245, 175)
	frame_regions[1][0][0] = Rect2(0, 260, 228, 185)
	frame_regions[1][1][0] = Rect2(228, 260, 230, 185)
	frame_regions[1][2][0] = Rect2(458, 260, 237, 185)
	frame_regions[1][3][0] = Rect2(695, 260, 227, 185)
	frame_regions[1][4][0] = Rect2(922, 260, 223, 185)
	frame_regions[1][5][0] = Rect2(1145, 260, 229, 185)
	frame_regions[2][0][0] = Rect2(0, 475, 228, 178)
	frame_regions[2][1][0] = Rect2(228, 475, 223, 178)
	frame_regions[2][2][0] = Rect2(451, 475, 228, 178)
	frame_regions[2][3][0] = Rect2(679, 475, 225, 178)
	frame_regions[2][4][0] = Rect2(904, 475, 230, 178)
	frame_regions[2][5][0] = Rect2(1134, 475, 240, 178)
	frame_regions[3][0][0] = Rect2(0, 658, 228, 252)
	frame_regions[3][1][0] = Rect2(228, 658, 229, 252)
	frame_regions[3][2][0] = Rect2(457, 658, 227, 252)
	frame_regions[3][3][0] = Rect2(684, 658, 221, 252)
	frame_regions[4][0][0] = Rect2(0, 930, 224, 180)
	frame_regions[4][1][0] = Rect2(224, 930, 229, 180)
	frame_regions[4][2][0] = Rect2(453, 930, 240, 180)
	frame_regions[4][3][0] = Rect2(693, 930, 220, 180)
	frame_regions[4][4][0] = Rect2(913, 930, 224, 180)
	frame_regions[4][5][0] = Rect2(1137, 930, 237, 180)
	frame_polygons = {
		3: {
			4: PackedVector2Array([
				Vector2(905, 658), Vector2(905, 910), Vector2(1145, 910), Vector2(1145, 885), Vector2(1144, 884),
				Vector2(1146, 883), Vector2(1144, 882), Vector2(1144, 881), Vector2(1145, 880), Vector2(1145, 875),
				Vector2(1144, 874), Vector2(1145, 873), Vector2(1144, 872), Vector2(1146, 871), Vector2(1145, 870),
				Vector2(1145, 855), Vector2(1148, 854), Vector2(1149, 853), Vector2(1149, 852), Vector2(1145, 851),
				Vector2(1146, 850), Vector2(1146, 849), Vector2(1147, 848), Vector2(1146, 847), Vector2(1148, 846),
				Vector2(1146, 845), Vector2(1148, 844), Vector2(1148, 843), Vector2(1147, 842), Vector2(1148, 841),
				Vector2(1144, 840), Vector2(1147, 839), Vector2(1147, 838), Vector2(1146, 837), Vector2(1146, 836),
				Vector2(1147, 835), Vector2(1147, 834), Vector2(1146, 833), Vector2(1146, 832), Vector2(1147, 831),
				Vector2(1147, 829), Vector2(1149, 828), Vector2(1149, 827), Vector2(1150, 826), Vector2(1150, 825),
				Vector2(1147, 824), Vector2(1147, 823), Vector2(1148, 822), Vector2(1148, 821), Vector2(1150, 820),
				Vector2(1150, 818), Vector2(1148, 817), Vector2(1149, 816), Vector2(1149, 815), Vector2(1150, 814),
				Vector2(1152, 813), Vector2(1151, 812), Vector2(1149, 811), Vector2(1152, 810), Vector2(1150, 809),
				Vector2(1154, 808), Vector2(1152, 807), Vector2(1153, 806), Vector2(1155, 805), Vector2(1154, 804),
				Vector2(1154, 802), Vector2(1156, 800), Vector2(1156, 799), Vector2(1148, 797), Vector2(1148, 796),
				Vector2(1145, 795), Vector2(1145, 794), Vector2(1149, 793), Vector2(1147, 792), Vector2(1147, 791),
				Vector2(1145, 790), Vector2(1145, 776), Vector2(1146, 775), Vector2(1146, 773), Vector2(1147, 772),
				Vector2(1149, 771), Vector2(1153, 770), Vector2(1155, 769), Vector2(1153, 768), Vector2(1153, 765),
				Vector2(1154, 764), Vector2(1154, 763), Vector2(1152, 762), Vector2(1152, 761), Vector2(1154, 760),
				Vector2(1150, 758), Vector2(1152, 757), Vector2(1149, 756), Vector2(1149, 755), Vector2(1151, 754),
				Vector2(1151, 753), Vector2(1148, 752), Vector2(1150, 751), Vector2(1148, 749), Vector2(1148, 745),
				Vector2(1146, 744), Vector2(1147, 743), Vector2(1146, 742), Vector2(1146, 741), Vector2(1145, 740),
				Vector2(1145, 738), Vector2(1146, 737), Vector2(1145, 736), Vector2(1145, 731), Vector2(1147, 729),
				Vector2(1145, 728), Vector2(1145, 724), Vector2(1146, 723), Vector2(1148, 722), Vector2(1151, 721),
				Vector2(1159, 719), Vector2(1159, 718), Vector2(1161, 717), Vector2(1158, 716), Vector2(1156, 714),
				Vector2(1158, 713), Vector2(1157, 712), Vector2(1154, 711), Vector2(1150, 707), Vector2(1147, 706),
				Vector2(1143, 705), Vector2(1147, 703), Vector2(1146, 702), Vector2(1146, 701), Vector2(1144, 700),
				Vector2(1146, 699), Vector2(1146, 698), Vector2(1145, 697), Vector2(1145, 658),
			]),
			5: PackedVector2Array([
				Vector2(1145, 658), Vector2(1145, 697), Vector2(1146, 698), Vector2(1146, 699), Vector2(1144, 700),
				Vector2(1146, 701), Vector2(1146, 702), Vector2(1147, 703), Vector2(1143, 705), Vector2(1147, 706),
				Vector2(1150, 707), Vector2(1154, 711), Vector2(1157, 712), Vector2(1158, 713), Vector2(1156, 714),
				Vector2(1158, 716), Vector2(1161, 717), Vector2(1159, 718), Vector2(1159, 719), Vector2(1151, 721),
				Vector2(1148, 722), Vector2(1146, 723), Vector2(1145, 724), Vector2(1145, 728), Vector2(1147, 729),
				Vector2(1145, 731), Vector2(1145, 736), Vector2(1146, 737), Vector2(1145, 738), Vector2(1145, 740),
				Vector2(1146, 741), Vector2(1146, 742), Vector2(1147, 743), Vector2(1146, 744), Vector2(1148, 745),
				Vector2(1148, 749), Vector2(1150, 751), Vector2(1148, 752), Vector2(1151, 753), Vector2(1151, 754),
				Vector2(1149, 755), Vector2(1149, 756), Vector2(1152, 757), Vector2(1150, 758), Vector2(1154, 760),
				Vector2(1152, 761), Vector2(1152, 762), Vector2(1154, 763), Vector2(1154, 764), Vector2(1153, 765),
				Vector2(1153, 768), Vector2(1155, 769), Vector2(1153, 770), Vector2(1149, 771), Vector2(1147, 772),
				Vector2(1146, 773), Vector2(1146, 775), Vector2(1145, 776), Vector2(1145, 790), Vector2(1147, 791),
				Vector2(1147, 792), Vector2(1149, 793), Vector2(1145, 794), Vector2(1145, 795), Vector2(1148, 796),
				Vector2(1148, 797), Vector2(1156, 799), Vector2(1156, 800), Vector2(1154, 802), Vector2(1154, 804),
				Vector2(1155, 805), Vector2(1153, 806), Vector2(1152, 807), Vector2(1154, 808), Vector2(1150, 809),
				Vector2(1152, 810), Vector2(1149, 811), Vector2(1151, 812), Vector2(1152, 813), Vector2(1150, 814),
				Vector2(1149, 815), Vector2(1149, 816), Vector2(1148, 817), Vector2(1150, 818), Vector2(1150, 820),
				Vector2(1148, 821), Vector2(1148, 822), Vector2(1147, 823), Vector2(1147, 824), Vector2(1150, 825),
				Vector2(1150, 826), Vector2(1149, 827), Vector2(1149, 828), Vector2(1147, 829), Vector2(1147, 831),
				Vector2(1146, 832), Vector2(1146, 833), Vector2(1147, 834), Vector2(1147, 835), Vector2(1146, 836),
				Vector2(1146, 837), Vector2(1147, 838), Vector2(1147, 839), Vector2(1144, 840), Vector2(1148, 841),
				Vector2(1147, 842), Vector2(1148, 843), Vector2(1148, 844), Vector2(1146, 845), Vector2(1148, 846),
				Vector2(1146, 847), Vector2(1147, 848), Vector2(1146, 849), Vector2(1146, 850), Vector2(1145, 851),
				Vector2(1149, 852), Vector2(1149, 853), Vector2(1148, 854), Vector2(1145, 855), Vector2(1145, 870),
				Vector2(1146, 871), Vector2(1144, 872), Vector2(1145, 873), Vector2(1144, 874), Vector2(1145, 875),
				Vector2(1145, 880), Vector2(1144, 881), Vector2(1144, 882), Vector2(1146, 883), Vector2(1144, 884),
				Vector2(1145, 885), Vector2(1145, 910), Vector2(1374, 910), Vector2(1374, 658),
			]),
		},
	}
