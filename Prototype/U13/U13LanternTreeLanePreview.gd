extends "res://Prototype/U13/U13ButcherLanePreview.gd"

func _configure_character() -> void:
	character_name = "LanternTree"
	bundled_sheet_path = "res://Prototype/U13/Assets/LanternTreeSprite.png"
	source_dimensions = Vector2(1377, 1142)
	source_body_height = 205.0
	source_shader_path = "res://Prototype/U13/U13VultureKey.gdshader"
	has_redraw = false
	use_redraw = false
	extra_animation_labels = {2: "Inspect idle", 3: "Inspect attack"}
	frame_regions = {}
	frame_polygons = {}
	var tops := [0, 235, 465, 685, 910]
	var bottoms := [225, 460, 682, 905, 1120]
	var grounds := [217, 446, 673, 894, 1104]
	for row in range(5):
		var poses: Array = []
		for column in range(6):
			var left := column * 229
			var right := (column + 1) * 229
			poses.append([Rect2(left, tops[row], right - left, bottoms[row] - tops[row]),
				Vector2(column * 229 + 115, grounds[row])])
		frame_regions[row] = poses
	# The chain-and-lantern extension is one wide pose, not two frames.
	frame_regions[3] = [
		[Rect2(0, 685, 229, 220), Vector2(115, 894)],
		[Rect2(229, 685, 229, 220), Vector2(344, 894)],
		[Rect2(458, 685, 460, 220), Vector2(573, 894)],
		[Rect2(918, 685, 243, 220), Vector2(1033, 894)],
		[Rect2(1161, 685, 216, 220), Vector2(1262, 894)],
	]

	# Follow the inter-frame gaps where wings, roots, and effects widen.
	frame_regions[0][0][0] = Rect2(0, 0, 237, 225)
	frame_regions[0][3][0] = Rect2(691, 0, 229, 225)
	frame_regions[0][4][0] = Rect2(920, 0, 231, 225)
	frame_regions[0][5][0] = Rect2(1151, 0, 226, 225)
	frame_regions[1][0][0] = Rect2(0, 235, 231, 225)
	frame_regions[1][1][0] = Rect2(231, 235, 232, 225)
	frame_regions[1][2][0] = Rect2(463, 235, 218, 225)
	frame_regions[1][3][0] = Rect2(681, 235, 228, 225)
	frame_regions[1][4][0] = Rect2(909, 235, 229, 225)
	frame_regions[1][5][0] = Rect2(1138, 235, 239, 225)
	frame_regions[2][0][0] = Rect2(0, 465, 226, 217)
	frame_regions[2][1][0] = Rect2(226, 465, 238, 217)
	frame_regions[2][2][0] = Rect2(464, 465, 226, 217)
	frame_regions[2][3][0] = Rect2(690, 465, 230, 217)
	frame_regions[2][4][0] = Rect2(920, 465, 231, 217)
	frame_regions[2][5][0] = Rect2(1151, 465, 226, 217)
	frame_regions[3][0][0] = Rect2(0, 685, 236, 220)
	frame_regions[3][1][0] = Rect2(236, 685, 218, 220)
	frame_regions[3][2][0] = Rect2(454, 685, 434, 220)
	frame_regions[4][0][0] = Rect2(0, 910, 233, 210)
	frame_polygons = {
		0: {
			1: PackedVector2Array([
				Vector2(237, 0), Vector2(237, 225), Vector2(458, 225), Vector2(458, 218), Vector2(462, 217),
				Vector2(459, 216), Vector2(467, 214), Vector2(468, 213), Vector2(468, 211), Vector2(465, 210),
				Vector2(463, 208), Vector2(463, 207), Vector2(461, 206), Vector2(461, 205), Vector2(459, 204),
				Vector2(458, 203), Vector2(461, 202), Vector2(461, 200), Vector2(457, 199), Vector2(456, 198),
				Vector2(460, 197), Vector2(458, 196), Vector2(458, 193), Vector2(457, 192), Vector2(457, 191),
				Vector2(458, 190), Vector2(458, 177), Vector2(459, 176), Vector2(459, 175), Vector2(458, 174),
				Vector2(458, 162), Vector2(459, 161), Vector2(457, 159), Vector2(458, 158), Vector2(458, 156),
				Vector2(459, 155), Vector2(459, 154), Vector2(458, 153), Vector2(459, 152), Vector2(459, 151),
				Vector2(458, 150), Vector2(458, 144), Vector2(459, 143), Vector2(459, 140), Vector2(458, 139),
				Vector2(458, 129), Vector2(456, 128), Vector2(458, 126), Vector2(458, 122), Vector2(459, 121),
				Vector2(459, 120), Vector2(458, 119), Vector2(458, 107), Vector2(459, 106), Vector2(459, 104),
				Vector2(458, 103), Vector2(458, 88), Vector2(457, 87), Vector2(457, 86), Vector2(458, 85),
				Vector2(458, 81), Vector2(457, 80), Vector2(457, 79), Vector2(458, 78), Vector2(458, 74),
				Vector2(457, 73), Vector2(458, 72), Vector2(458, 71), Vector2(457, 70), Vector2(458, 69),
				Vector2(458, 52), Vector2(459, 51), Vector2(457, 50), Vector2(459, 49), Vector2(459, 48),
				Vector2(458, 47), Vector2(458, 43), Vector2(459, 42), Vector2(456, 41), Vector2(458, 40),
				Vector2(458, 21), Vector2(459, 20), Vector2(457, 19), Vector2(458, 18), Vector2(458, 0),
			]),
			2: PackedVector2Array([
				Vector2(458, 0), Vector2(458, 18), Vector2(457, 19), Vector2(459, 20), Vector2(458, 21),
				Vector2(458, 40), Vector2(456, 41), Vector2(459, 42), Vector2(458, 43), Vector2(458, 47),
				Vector2(459, 48), Vector2(459, 49), Vector2(457, 50), Vector2(459, 51), Vector2(458, 52),
				Vector2(458, 69), Vector2(457, 70), Vector2(458, 71), Vector2(458, 72), Vector2(457, 73),
				Vector2(458, 74), Vector2(458, 78), Vector2(457, 79), Vector2(457, 80), Vector2(458, 81),
				Vector2(458, 85), Vector2(457, 86), Vector2(457, 87), Vector2(458, 88), Vector2(458, 103),
				Vector2(459, 104), Vector2(459, 106), Vector2(458, 107), Vector2(458, 119), Vector2(459, 120),
				Vector2(459, 121), Vector2(458, 122), Vector2(458, 126), Vector2(456, 128), Vector2(458, 129),
				Vector2(458, 139), Vector2(459, 140), Vector2(459, 143), Vector2(458, 144), Vector2(458, 150),
				Vector2(459, 151), Vector2(459, 152), Vector2(458, 153), Vector2(459, 154), Vector2(459, 155),
				Vector2(458, 156), Vector2(458, 158), Vector2(457, 159), Vector2(459, 161), Vector2(458, 162),
				Vector2(458, 174), Vector2(459, 175), Vector2(459, 176), Vector2(458, 177), Vector2(458, 190),
				Vector2(457, 191), Vector2(457, 192), Vector2(458, 193), Vector2(458, 196), Vector2(460, 197),
				Vector2(456, 198), Vector2(457, 199), Vector2(461, 200), Vector2(461, 202), Vector2(458, 203),
				Vector2(459, 204), Vector2(461, 205), Vector2(461, 206), Vector2(463, 207), Vector2(463, 208),
				Vector2(465, 210), Vector2(468, 211), Vector2(468, 213), Vector2(467, 214), Vector2(459, 216),
				Vector2(462, 217), Vector2(458, 218), Vector2(458, 225), Vector2(691, 225), Vector2(691, 0),
			]),
		},
		3: {
			3: PackedVector2Array([
				Vector2(888, 685), Vector2(888, 905), Vector2(1145, 905), Vector2(1145, 900), Vector2(1146, 899),
				Vector2(1145, 898), Vector2(1145, 892), Vector2(1147, 891), Vector2(1147, 890), Vector2(1145, 888),
				Vector2(1145, 877), Vector2(1146, 876), Vector2(1145, 875), Vector2(1147, 874), Vector2(1145, 872),
				Vector2(1145, 870), Vector2(1142, 869), Vector2(1143, 868), Vector2(1142, 867), Vector2(1142, 866),
				Vector2(1146, 865), Vector2(1147, 864), Vector2(1147, 863), Vector2(1146, 862), Vector2(1146, 860),
				Vector2(1144, 859), Vector2(1144, 858), Vector2(1143, 857), Vector2(1145, 856), Vector2(1145, 855),
				Vector2(1143, 854), Vector2(1144, 853), Vector2(1147, 852), Vector2(1147, 851), Vector2(1145, 850),
				Vector2(1145, 845), Vector2(1143, 844), Vector2(1139, 843), Vector2(1138, 842), Vector2(1138, 840),
				Vector2(1137, 839), Vector2(1137, 838), Vector2(1138, 837), Vector2(1138, 833), Vector2(1137, 832),
				Vector2(1137, 831), Vector2(1136, 830), Vector2(1136, 829), Vector2(1137, 828), Vector2(1137, 826),
				Vector2(1136, 825), Vector2(1136, 824), Vector2(1140, 823), Vector2(1143, 822), Vector2(1143, 821),
				Vector2(1146, 820), Vector2(1142, 818), Vector2(1142, 817), Vector2(1146, 816), Vector2(1146, 815),
				Vector2(1154, 813), Vector2(1155, 812), Vector2(1155, 811), Vector2(1152, 810), Vector2(1148, 809),
				Vector2(1152, 808), Vector2(1152, 806), Vector2(1151, 805), Vector2(1153, 804), Vector2(1152, 803),
				Vector2(1149, 802), Vector2(1151, 801), Vector2(1148, 800), Vector2(1147, 799), Vector2(1149, 798),
				Vector2(1145, 797), Vector2(1141, 795), Vector2(1144, 794), Vector2(1146, 793), Vector2(1145, 792),
				Vector2(1145, 790), Vector2(1146, 789), Vector2(1144, 788), Vector2(1144, 787), Vector2(1145, 786),
				Vector2(1145, 775), Vector2(1144, 774), Vector2(1146, 773), Vector2(1145, 772), Vector2(1145, 764),
				Vector2(1144, 763), Vector2(1146, 762), Vector2(1145, 761), Vector2(1145, 752), Vector2(1144, 751),
				Vector2(1146, 750), Vector2(1144, 748), Vector2(1145, 747), Vector2(1145, 746), Vector2(1146, 745),
				Vector2(1145, 744), Vector2(1145, 722), Vector2(1144, 721), Vector2(1145, 720), Vector2(1145, 719),
				Vector2(1146, 718), Vector2(1145, 717), Vector2(1145, 709), Vector2(1144, 708), Vector2(1145, 707),
				Vector2(1145, 701), Vector2(1146, 700), Vector2(1145, 699), Vector2(1145, 685),
			]),
			4: PackedVector2Array([
				Vector2(1145, 685), Vector2(1145, 699), Vector2(1146, 700), Vector2(1145, 701), Vector2(1145, 707),
				Vector2(1144, 708), Vector2(1145, 709), Vector2(1145, 717), Vector2(1146, 718), Vector2(1145, 719),
				Vector2(1145, 720), Vector2(1144, 721), Vector2(1145, 722), Vector2(1145, 744), Vector2(1146, 745),
				Vector2(1145, 746), Vector2(1145, 747), Vector2(1144, 748), Vector2(1146, 750), Vector2(1144, 751),
				Vector2(1145, 752), Vector2(1145, 761), Vector2(1146, 762), Vector2(1144, 763), Vector2(1145, 764),
				Vector2(1145, 772), Vector2(1146, 773), Vector2(1144, 774), Vector2(1145, 775), Vector2(1145, 786),
				Vector2(1144, 787), Vector2(1144, 788), Vector2(1146, 789), Vector2(1145, 790), Vector2(1145, 792),
				Vector2(1146, 793), Vector2(1144, 794), Vector2(1141, 795), Vector2(1145, 797), Vector2(1149, 798),
				Vector2(1147, 799), Vector2(1148, 800), Vector2(1151, 801), Vector2(1149, 802), Vector2(1152, 803),
				Vector2(1153, 804), Vector2(1151, 805), Vector2(1152, 806), Vector2(1152, 808), Vector2(1148, 809),
				Vector2(1152, 810), Vector2(1155, 811), Vector2(1155, 812), Vector2(1154, 813), Vector2(1146, 815),
				Vector2(1146, 816), Vector2(1142, 817), Vector2(1142, 818), Vector2(1146, 820), Vector2(1143, 821),
				Vector2(1143, 822), Vector2(1140, 823), Vector2(1136, 824), Vector2(1136, 825), Vector2(1137, 826),
				Vector2(1137, 828), Vector2(1136, 829), Vector2(1136, 830), Vector2(1137, 831), Vector2(1137, 832),
				Vector2(1138, 833), Vector2(1138, 837), Vector2(1137, 838), Vector2(1137, 839), Vector2(1138, 840),
				Vector2(1138, 842), Vector2(1139, 843), Vector2(1143, 844), Vector2(1145, 845), Vector2(1145, 850),
				Vector2(1147, 851), Vector2(1147, 852), Vector2(1144, 853), Vector2(1143, 854), Vector2(1145, 855),
				Vector2(1145, 856), Vector2(1143, 857), Vector2(1144, 858), Vector2(1144, 859), Vector2(1146, 860),
				Vector2(1146, 862), Vector2(1147, 863), Vector2(1147, 864), Vector2(1146, 865), Vector2(1142, 866),
				Vector2(1142, 867), Vector2(1143, 868), Vector2(1142, 869), Vector2(1145, 870), Vector2(1145, 872),
				Vector2(1147, 874), Vector2(1145, 875), Vector2(1146, 876), Vector2(1145, 877), Vector2(1145, 888),
				Vector2(1147, 890), Vector2(1147, 891), Vector2(1145, 892), Vector2(1145, 898), Vector2(1146, 899),
				Vector2(1145, 900), Vector2(1145, 905), Vector2(1377, 905), Vector2(1377, 685),
			]),
		},
		4: {
			1: PackedVector2Array([
				Vector2(233, 910), Vector2(233, 1120), Vector2(458, 1120), Vector2(458, 1116), Vector2(459, 1115),
				Vector2(459, 1113), Vector2(458, 1112), Vector2(458, 1106), Vector2(459, 1105), Vector2(458, 1104),
				Vector2(459, 1103), Vector2(459, 1102), Vector2(461, 1101), Vector2(465, 1100), Vector2(468, 1099),
				Vector2(470, 1098), Vector2(470, 1096), Vector2(468, 1095), Vector2(468, 1094), Vector2(466, 1093),
				Vector2(466, 1092), Vector2(467, 1091), Vector2(465, 1090), Vector2(457, 1088), Vector2(460, 1087),
				Vector2(456, 1086), Vector2(459, 1085), Vector2(461, 1084), Vector2(461, 1083), Vector2(457, 1082),
				Vector2(461, 1081), Vector2(461, 1079), Vector2(457, 1078), Vector2(461, 1077), Vector2(463, 1076),
				Vector2(463, 1069), Vector2(460, 1068), Vector2(464, 1067), Vector2(466, 1066), Vector2(465, 1065),
				Vector2(465, 1064), Vector2(464, 1063), Vector2(460, 1062), Vector2(460, 1061), Vector2(462, 1060),
				Vector2(459, 1059), Vector2(459, 1056), Vector2(458, 1055), Vector2(459, 1054), Vector2(457, 1053),
				Vector2(460, 1052), Vector2(458, 1050), Vector2(459, 1049), Vector2(459, 1048), Vector2(458, 1047),
				Vector2(458, 1019), Vector2(459, 1018), Vector2(459, 1017), Vector2(457, 1015), Vector2(458, 1014),
				Vector2(458, 1010), Vector2(456, 1009), Vector2(458, 1007), Vector2(458, 1003), Vector2(457, 1002),
				Vector2(458, 1001), Vector2(458, 1000), Vector2(456, 998), Vector2(458, 996), Vector2(458, 984),
				Vector2(459, 983), Vector2(458, 982), Vector2(458, 970), Vector2(457, 969), Vector2(458, 968),
				Vector2(458, 967), Vector2(457, 966), Vector2(458, 965), Vector2(458, 955), Vector2(459, 954),
				Vector2(459, 950), Vector2(458, 949), Vector2(459, 948), Vector2(459, 945), Vector2(460, 944),
				Vector2(460, 943), Vector2(458, 942), Vector2(458, 926), Vector2(456, 925), Vector2(458, 924),
				Vector2(458, 919), Vector2(459, 918), Vector2(457, 917), Vector2(458, 916), Vector2(458, 910),
			]),
			2: PackedVector2Array([
				Vector2(458, 910), Vector2(458, 916), Vector2(457, 917), Vector2(459, 918), Vector2(458, 919),
				Vector2(458, 924), Vector2(456, 925), Vector2(458, 926), Vector2(458, 942), Vector2(460, 943),
				Vector2(460, 944), Vector2(459, 945), Vector2(459, 948), Vector2(458, 949), Vector2(459, 950),
				Vector2(459, 954), Vector2(458, 955), Vector2(458, 965), Vector2(457, 966), Vector2(458, 967),
				Vector2(458, 968), Vector2(457, 969), Vector2(458, 970), Vector2(458, 982), Vector2(459, 983),
				Vector2(458, 984), Vector2(458, 996), Vector2(456, 998), Vector2(458, 1000), Vector2(458, 1001),
				Vector2(457, 1002), Vector2(458, 1003), Vector2(458, 1007), Vector2(456, 1009), Vector2(458, 1010),
				Vector2(458, 1014), Vector2(457, 1015), Vector2(459, 1017), Vector2(459, 1018), Vector2(458, 1019),
				Vector2(458, 1047), Vector2(459, 1048), Vector2(459, 1049), Vector2(458, 1050), Vector2(460, 1052),
				Vector2(457, 1053), Vector2(459, 1054), Vector2(458, 1055), Vector2(459, 1056), Vector2(459, 1059),
				Vector2(462, 1060), Vector2(460, 1061), Vector2(460, 1062), Vector2(464, 1063), Vector2(465, 1064),
				Vector2(465, 1065), Vector2(466, 1066), Vector2(464, 1067), Vector2(460, 1068), Vector2(463, 1069),
				Vector2(463, 1076), Vector2(461, 1077), Vector2(457, 1078), Vector2(461, 1079), Vector2(461, 1081),
				Vector2(457, 1082), Vector2(461, 1083), Vector2(461, 1084), Vector2(459, 1085), Vector2(456, 1086),
				Vector2(460, 1087), Vector2(457, 1088), Vector2(465, 1090), Vector2(467, 1091), Vector2(466, 1092),
				Vector2(466, 1093), Vector2(468, 1094), Vector2(468, 1095), Vector2(470, 1096), Vector2(470, 1098),
				Vector2(468, 1099), Vector2(465, 1100), Vector2(461, 1101), Vector2(459, 1102), Vector2(459, 1103),
				Vector2(458, 1104), Vector2(459, 1105), Vector2(458, 1106), Vector2(458, 1112), Vector2(459, 1113),
				Vector2(459, 1115), Vector2(458, 1116), Vector2(458, 1120), Vector2(687, 1120), Vector2(687, 1116),
				Vector2(689, 1115), Vector2(687, 1114), Vector2(687, 1103), Vector2(689, 1102), Vector2(689, 1101),
				Vector2(691, 1099), Vector2(703, 1096), Vector2(704, 1095), Vector2(704, 1094), Vector2(696, 1092),
				Vector2(694, 1090), Vector2(694, 1089), Vector2(690, 1088), Vector2(688, 1087), Vector2(684, 1086),
				Vector2(683, 1085), Vector2(687, 1084), Vector2(685, 1082), Vector2(687, 1081), Vector2(688, 1080),
				Vector2(688, 1079), Vector2(687, 1078), Vector2(687, 1073), Vector2(686, 1072), Vector2(686, 1071),
				Vector2(687, 1070), Vector2(687, 1056), Vector2(686, 1055), Vector2(686, 1054), Vector2(687, 1053),
				Vector2(687, 1030), Vector2(686, 1029), Vector2(686, 1028), Vector2(687, 1027), Vector2(687, 1024),
				Vector2(689, 1023), Vector2(687, 1022), Vector2(687, 1015), Vector2(686, 1014), Vector2(687, 1013),
				Vector2(687, 1003), Vector2(686, 1002), Vector2(686, 1001), Vector2(687, 1000), Vector2(687, 997),
				Vector2(688, 996), Vector2(687, 995), Vector2(687, 993), Vector2(688, 992), Vector2(687, 991),
				Vector2(687, 980), Vector2(686, 979), Vector2(689, 978), Vector2(689, 977), Vector2(687, 976),
				Vector2(687, 972), Vector2(689, 971), Vector2(689, 968), Vector2(687, 966), Vector2(687, 964),
				Vector2(688, 963), Vector2(688, 962), Vector2(687, 961), Vector2(687, 948), Vector2(686, 947),
				Vector2(686, 946), Vector2(687, 945), Vector2(687, 943), Vector2(689, 942), Vector2(689, 941),
				Vector2(687, 940), Vector2(687, 921), Vector2(689, 920), Vector2(689, 919), Vector2(687, 918),
				Vector2(687, 910),
			]),
			3: PackedVector2Array([
				Vector2(687, 910), Vector2(687, 918), Vector2(689, 919), Vector2(689, 920), Vector2(687, 921),
				Vector2(687, 940), Vector2(689, 941), Vector2(689, 942), Vector2(687, 943), Vector2(687, 945),
				Vector2(686, 946), Vector2(686, 947), Vector2(687, 948), Vector2(687, 961), Vector2(688, 962),
				Vector2(688, 963), Vector2(687, 964), Vector2(687, 966), Vector2(689, 968), Vector2(689, 971),
				Vector2(687, 972), Vector2(687, 976), Vector2(689, 977), Vector2(689, 978), Vector2(686, 979),
				Vector2(687, 980), Vector2(687, 991), Vector2(688, 992), Vector2(687, 993), Vector2(687, 995),
				Vector2(688, 996), Vector2(687, 997), Vector2(687, 1000), Vector2(686, 1001), Vector2(686, 1002),
				Vector2(687, 1003), Vector2(687, 1013), Vector2(686, 1014), Vector2(687, 1015), Vector2(687, 1022),
				Vector2(689, 1023), Vector2(687, 1024), Vector2(687, 1027), Vector2(686, 1028), Vector2(686, 1029),
				Vector2(687, 1030), Vector2(687, 1053), Vector2(686, 1054), Vector2(686, 1055), Vector2(687, 1056),
				Vector2(687, 1070), Vector2(686, 1071), Vector2(686, 1072), Vector2(687, 1073), Vector2(687, 1078),
				Vector2(688, 1079), Vector2(688, 1080), Vector2(687, 1081), Vector2(685, 1082), Vector2(687, 1084),
				Vector2(683, 1085), Vector2(684, 1086), Vector2(688, 1087), Vector2(690, 1088), Vector2(694, 1089),
				Vector2(694, 1090), Vector2(696, 1092), Vector2(704, 1094), Vector2(704, 1095), Vector2(703, 1096),
				Vector2(691, 1099), Vector2(689, 1101), Vector2(689, 1102), Vector2(687, 1103), Vector2(687, 1114),
				Vector2(689, 1115), Vector2(687, 1116), Vector2(687, 1120), Vector2(916, 1120), Vector2(916, 1115),
				Vector2(915, 1114), Vector2(916, 1113), Vector2(916, 1109), Vector2(928, 1106), Vector2(929, 1105),
				Vector2(927, 1103), Vector2(931, 1101), Vector2(935, 1100), Vector2(933, 1098), Vector2(930, 1097),
				Vector2(924, 1094), Vector2(922, 1092), Vector2(920, 1091), Vector2(918, 1089), Vector2(922, 1088),
				Vector2(922, 1087), Vector2(919, 1086), Vector2(912, 1079), Vector2(912, 1078), Vector2(902, 1068),
				Vector2(910, 1066), Vector2(914, 1064), Vector2(914, 1063), Vector2(913, 1062), Vector2(913, 1061),
				Vector2(914, 1060), Vector2(911, 1059), Vector2(915, 1058), Vector2(915, 1056), Vector2(916, 1055),
				Vector2(916, 1052), Vector2(918, 1050), Vector2(917, 1049), Vector2(917, 1048), Vector2(918, 1047),
				Vector2(918, 1039), Vector2(915, 1038), Vector2(915, 1037), Vector2(916, 1036), Vector2(916, 1032),
				Vector2(919, 1031), Vector2(916, 1030), Vector2(916, 1029), Vector2(918, 1028), Vector2(922, 1027),
				Vector2(918, 1026), Vector2(918, 1025), Vector2(922, 1024), Vector2(921, 1023), Vector2(925, 1022),
				Vector2(923, 1020), Vector2(919, 1019), Vector2(916, 1018), Vector2(914, 1017), Vector2(918, 1015),
				Vector2(917, 1014), Vector2(917, 1013), Vector2(916, 1012), Vector2(916, 1008), Vector2(917, 1007),
				Vector2(916, 1006), Vector2(916, 1000), Vector2(914, 999), Vector2(916, 998), Vector2(916, 976),
				Vector2(915, 975), Vector2(917, 974), Vector2(916, 973), Vector2(916, 946), Vector2(917, 945),
				Vector2(916, 944), Vector2(916, 910),
			]),
			4: PackedVector2Array([
				Vector2(916, 910), Vector2(916, 944), Vector2(917, 945), Vector2(916, 946), Vector2(916, 973),
				Vector2(917, 974), Vector2(915, 975), Vector2(916, 976), Vector2(916, 998), Vector2(914, 999),
				Vector2(916, 1000), Vector2(916, 1006), Vector2(917, 1007), Vector2(916, 1008), Vector2(916, 1012),
				Vector2(917, 1013), Vector2(917, 1014), Vector2(918, 1015), Vector2(914, 1017), Vector2(916, 1018),
				Vector2(919, 1019), Vector2(923, 1020), Vector2(925, 1022), Vector2(921, 1023), Vector2(922, 1024),
				Vector2(918, 1025), Vector2(918, 1026), Vector2(922, 1027), Vector2(918, 1028), Vector2(916, 1029),
				Vector2(916, 1030), Vector2(919, 1031), Vector2(916, 1032), Vector2(916, 1036), Vector2(915, 1037),
				Vector2(915, 1038), Vector2(918, 1039), Vector2(918, 1047), Vector2(917, 1048), Vector2(917, 1049),
				Vector2(918, 1050), Vector2(916, 1052), Vector2(916, 1055), Vector2(915, 1056), Vector2(915, 1058),
				Vector2(911, 1059), Vector2(914, 1060), Vector2(913, 1061), Vector2(913, 1062), Vector2(914, 1063),
				Vector2(914, 1064), Vector2(910, 1066), Vector2(902, 1068), Vector2(912, 1078), Vector2(912, 1079),
				Vector2(919, 1086), Vector2(922, 1087), Vector2(922, 1088), Vector2(918, 1089), Vector2(920, 1091),
				Vector2(922, 1092), Vector2(924, 1094), Vector2(930, 1097), Vector2(933, 1098), Vector2(935, 1100),
				Vector2(931, 1101), Vector2(927, 1103), Vector2(929, 1105), Vector2(928, 1106), Vector2(916, 1109),
				Vector2(916, 1113), Vector2(915, 1114), Vector2(916, 1115), Vector2(916, 1120), Vector2(1145, 1120),
				Vector2(1145, 1118), Vector2(1146, 1117), Vector2(1145, 1116), Vector2(1145, 1107), Vector2(1146, 1106),
				Vector2(1145, 1105), Vector2(1145, 1102), Vector2(1146, 1101), Vector2(1145, 1100), Vector2(1149, 1098),
				Vector2(1157, 1096), Vector2(1155, 1095), Vector2(1155, 1094), Vector2(1152, 1093), Vector2(1151, 1092),
				Vector2(1149, 1091), Vector2(1145, 1090), Vector2(1145, 1088), Vector2(1144, 1087), Vector2(1145, 1086),
				Vector2(1144, 1085), Vector2(1144, 1083), Vector2(1145, 1082), Vector2(1145, 1079), Vector2(1143, 1078),
				Vector2(1143, 1077), Vector2(1147, 1076), Vector2(1148, 1075), Vector2(1148, 1074), Vector2(1147, 1073),
				Vector2(1147, 1072), Vector2(1145, 1070), Vector2(1145, 1068), Vector2(1147, 1067), Vector2(1147, 1066),
				Vector2(1143, 1065), Vector2(1143, 1061), Vector2(1147, 1060), Vector2(1147, 1059), Vector2(1145, 1058),
				Vector2(1145, 1049), Vector2(1146, 1048), Vector2(1145, 1047), Vector2(1146, 1046), Vector2(1146, 1045),
				Vector2(1145, 1044), Vector2(1145, 982), Vector2(1146, 981), Vector2(1145, 980), Vector2(1145, 925),
				Vector2(1144, 924), Vector2(1145, 923), Vector2(1145, 914), Vector2(1144, 913), Vector2(1145, 912),
				Vector2(1145, 911), Vector2(1146, 910),
			]),
			5: PackedVector2Array([
				Vector2(1146, 910), Vector2(1145, 911), Vector2(1145, 912), Vector2(1144, 913), Vector2(1145, 914),
				Vector2(1145, 923), Vector2(1144, 924), Vector2(1145, 925), Vector2(1145, 980), Vector2(1146, 981),
				Vector2(1145, 982), Vector2(1145, 1044), Vector2(1146, 1045), Vector2(1146, 1046), Vector2(1145, 1047),
				Vector2(1146, 1048), Vector2(1145, 1049), Vector2(1145, 1058), Vector2(1147, 1059), Vector2(1147, 1060),
				Vector2(1143, 1061), Vector2(1143, 1065), Vector2(1147, 1066), Vector2(1147, 1067), Vector2(1145, 1068),
				Vector2(1145, 1070), Vector2(1147, 1072), Vector2(1147, 1073), Vector2(1148, 1074), Vector2(1148, 1075),
				Vector2(1147, 1076), Vector2(1143, 1077), Vector2(1143, 1078), Vector2(1145, 1079), Vector2(1145, 1082),
				Vector2(1144, 1083), Vector2(1144, 1085), Vector2(1145, 1086), Vector2(1144, 1087), Vector2(1145, 1088),
				Vector2(1145, 1090), Vector2(1149, 1091), Vector2(1151, 1092), Vector2(1152, 1093), Vector2(1155, 1094),
				Vector2(1155, 1095), Vector2(1157, 1096), Vector2(1149, 1098), Vector2(1145, 1100), Vector2(1146, 1101),
				Vector2(1145, 1102), Vector2(1145, 1105), Vector2(1146, 1106), Vector2(1145, 1107), Vector2(1145, 1116),
				Vector2(1146, 1117), Vector2(1145, 1118), Vector2(1145, 1120), Vector2(1377, 1120), Vector2(1377, 910),
			]),
		},
	}
