extends "res://Prototype/U13/U13ButcherLanePreview.gd"

func _configure_character() -> void:
	character_name = "Ratton"
	bundled_sheet_path = "res://Prototype/U13/Assets/RattonSprite.png"
	source_dimensions = Vector2(1536, 1024)
	source_body_height = 155.0
	source_shader_path = ''
	has_redraw = false
	use_redraw = false
	extra_animation_labels = {2: "Inspect idle", 3: "Inspect attack"}
	frame_regions = {}
	frame_polygons = {}
	frame_regions[0] = [
		[Rect2(0, 41, 314, 178), Vector2(153.5, 206)],
		[Rect2(314, 41, 301, 178), Vector2(460.5, 206)],
		[Rect2(615, 41, 295, 178), Vector2(767.5, 206)],
		[Rect2(910, 41, 301, 178), Vector2(1074.5, 206)],
		[Rect2(1211, 41, 325, 178), Vector2(1381.5, 206)],
	]
	frame_regions[1] = [
		[Rect2(0, 259, 305, 171), Vector2(153.5, 417)],
		[Rect2(305, 259, 301, 171), Vector2(460.5, 417)],
		[Rect2(606, 259, 304, 171), Vector2(767.5, 417)],
		[Rect2(910, 259, 308, 171), Vector2(1074.5, 417)],
		[Rect2(1218, 259, 318, 171), Vector2(1381.5, 417)],
	]
	frame_regions[2] = [
		[Rect2(0, 470, 312, 165), Vector2(153.5, 622)],
		[Rect2(312, 470, 298, 165), Vector2(460.5, 622)],
		[Rect2(610, 470, 311, 165), Vector2(767.5, 622)],
	]
	frame_regions[3] = [
		[Rect2(0, 675, 307, 159), Vector2(153.5, 823)],
		[Rect2(307, 675, 329, 159), Vector2(460.5, 823)],
		[Rect2(613, 675, 330, 159), Vector2(767.5, 823)],
		[Rect2(920, 675, 330, 159), Vector2(1074.5, 823)],
		[Rect2(1228, 675, 308, 159), Vector2(1381.5, 823)],
	]
	frame_regions[4] = [
		[Rect2(0, 849, 267, 175), Vector2(128.0, 1006)],
		[Rect2(267, 849, 256, 175), Vector2(384.0, 1006)],
		[Rect2(523, 849, 253, 175), Vector2(640.0, 1006)],
		[Rect2(776, 849, 252, 175), Vector2(896.0, 1006)],
		[Rect2(1028, 849, 249, 175), Vector2(1152.0, 1006)],
		[Rect2(1277, 849, 259, 175), Vector2(1408.0, 1006)],
	]
	frame_polygons = {
		3: {
			1: PackedVector2Array([
				Vector2(307, 675), Vector2(307, 834), Vector2(614, 834), Vector2(614, 790), Vector2(613, 789),
				Vector2(616, 788), Vector2(620, 787), Vector2(620, 784), Vector2(622, 783), Vector2(620, 782),
				Vector2(620, 777), Vector2(617, 776), Vector2(617, 774), Vector2(620, 773), Vector2(621, 772),
				Vector2(617, 771), Vector2(621, 770), Vector2(622, 769), Vector2(624, 768), Vector2(627, 767),
				Vector2(629, 766), Vector2(629, 765), Vector2(631, 764), Vector2(631, 763), Vector2(630, 762),
				Vector2(632, 761), Vector2(630, 760), Vector2(630, 759), Vector2(632, 758), Vector2(632, 757),
				Vector2(636, 756), Vector2(636, 754), Vector2(632, 753), Vector2(636, 752), Vector2(636, 746),
				Vector2(630, 743), Vector2(632, 742), Vector2(636, 741), Vector2(636, 738), Vector2(635, 737),
				Vector2(632, 736), Vector2(630, 734), Vector2(622, 730), Vector2(624, 729), Vector2(620, 728),
				Vector2(617, 727), Vector2(616, 726), Vector2(614, 725), Vector2(615, 724), Vector2(614, 723),
				Vector2(616, 722), Vector2(614, 721), Vector2(614, 675),
			]),
			2: PackedVector2Array([
				Vector2(614, 675), Vector2(614, 721), Vector2(616, 722), Vector2(614, 723), Vector2(615, 724),
				Vector2(614, 725), Vector2(616, 726), Vector2(617, 727), Vector2(620, 728), Vector2(624, 729),
				Vector2(622, 730), Vector2(630, 734), Vector2(632, 736), Vector2(635, 737), Vector2(636, 738),
				Vector2(636, 741), Vector2(632, 742), Vector2(630, 743), Vector2(636, 746), Vector2(636, 752),
				Vector2(632, 753), Vector2(636, 754), Vector2(636, 756), Vector2(632, 757), Vector2(632, 758),
				Vector2(630, 759), Vector2(630, 760), Vector2(632, 761), Vector2(630, 762), Vector2(631, 763),
				Vector2(631, 764), Vector2(629, 765), Vector2(629, 766), Vector2(627, 767), Vector2(624, 768),
				Vector2(622, 769), Vector2(621, 770), Vector2(617, 771), Vector2(621, 772), Vector2(620, 773),
				Vector2(617, 774), Vector2(617, 776), Vector2(620, 777), Vector2(620, 782), Vector2(622, 783),
				Vector2(620, 784), Vector2(620, 787), Vector2(616, 788), Vector2(613, 789), Vector2(614, 790),
				Vector2(614, 834), Vector2(921, 834), Vector2(921, 787), Vector2(920, 786), Vector2(923, 785),
				Vector2(924, 784), Vector2(923, 783), Vector2(923, 782), Vector2(924, 781), Vector2(924, 778),
				Vector2(920, 777), Vector2(922, 776), Vector2(923, 775), Vector2(922, 774), Vector2(922, 766),
				Vector2(923, 765), Vector2(922, 764), Vector2(922, 761), Vector2(921, 760), Vector2(921, 759),
				Vector2(923, 758), Vector2(922, 757), Vector2(923, 756), Vector2(923, 755), Vector2(921, 753),
				Vector2(921, 744), Vector2(924, 743), Vector2(940, 739), Vector2(940, 727), Vector2(942, 726),
				Vector2(940, 725), Vector2(940, 723), Vector2(941, 722), Vector2(941, 721), Vector2(937, 720),
				Vector2(937, 719), Vector2(940, 718), Vector2(939, 717), Vector2(943, 716), Vector2(943, 711),
				Vector2(940, 710), Vector2(940, 709), Vector2(942, 708), Vector2(941, 707), Vector2(943, 706),
				Vector2(942, 705), Vector2(943, 704), Vector2(943, 703), Vector2(940, 702), Vector2(938, 701),
				Vector2(940, 700), Vector2(938, 699), Vector2(937, 698), Vector2(943, 696), Vector2(942, 695),
				Vector2(942, 693), Vector2(934, 691), Vector2(931, 690), Vector2(931, 688), Vector2(930, 687),
				Vector2(922, 685), Vector2(921, 684), Vector2(921, 675),
			]),
			3: PackedVector2Array([
				Vector2(921, 675), Vector2(921, 684), Vector2(922, 685), Vector2(930, 687), Vector2(931, 688),
				Vector2(931, 690), Vector2(934, 691), Vector2(942, 693), Vector2(942, 695), Vector2(943, 696),
				Vector2(937, 698), Vector2(938, 699), Vector2(940, 700), Vector2(938, 701), Vector2(940, 702),
				Vector2(943, 703), Vector2(943, 704), Vector2(942, 705), Vector2(943, 706), Vector2(941, 707),
				Vector2(942, 708), Vector2(940, 709), Vector2(940, 710), Vector2(943, 711), Vector2(943, 716),
				Vector2(939, 717), Vector2(940, 718), Vector2(937, 719), Vector2(937, 720), Vector2(941, 721),
				Vector2(941, 722), Vector2(940, 723), Vector2(940, 725), Vector2(942, 726), Vector2(940, 727),
				Vector2(940, 739), Vector2(924, 743), Vector2(921, 744), Vector2(921, 753), Vector2(923, 755),
				Vector2(923, 756), Vector2(922, 757), Vector2(923, 758), Vector2(921, 759), Vector2(921, 760),
				Vector2(922, 761), Vector2(922, 764), Vector2(923, 765), Vector2(922, 766), Vector2(922, 774),
				Vector2(923, 775), Vector2(922, 776), Vector2(920, 777), Vector2(924, 778), Vector2(924, 781),
				Vector2(923, 782), Vector2(923, 783), Vector2(924, 784), Vector2(923, 785), Vector2(920, 786),
				Vector2(921, 787), Vector2(921, 834), Vector2(1228, 834), Vector2(1228, 782), Vector2(1229, 781),
				Vector2(1245, 777), Vector2(1243, 776), Vector2(1245, 775), Vector2(1245, 773), Vector2(1243, 772),
				Vector2(1243, 770), Vector2(1245, 769), Vector2(1245, 765), Vector2(1246, 764), Vector2(1246, 758),
				Vector2(1247, 757), Vector2(1243, 756), Vector2(1243, 755), Vector2(1244, 754), Vector2(1244, 753),
				Vector2(1246, 752), Vector2(1250, 751), Vector2(1250, 744), Vector2(1248, 743), Vector2(1248, 742),
				Vector2(1247, 741), Vector2(1245, 740), Vector2(1246, 739), Vector2(1250, 738), Vector2(1250, 733),
				Vector2(1246, 731), Vector2(1250, 730), Vector2(1250, 718), Vector2(1238, 715), Vector2(1235, 714),
				Vector2(1235, 711), Vector2(1234, 710), Vector2(1234, 707), Vector2(1232, 706), Vector2(1234, 705),
				Vector2(1234, 704), Vector2(1236, 703), Vector2(1236, 702), Vector2(1238, 701), Vector2(1237, 700),
				Vector2(1234, 699), Vector2(1235, 698), Vector2(1232, 697), Vector2(1230, 696), Vector2(1230, 695),
				Vector2(1231, 694), Vector2(1231, 693), Vector2(1230, 692), Vector2(1230, 690), Vector2(1228, 689),
				Vector2(1228, 675),
			]),
			4: PackedVector2Array([
				Vector2(1228, 675), Vector2(1228, 689), Vector2(1230, 690), Vector2(1230, 692), Vector2(1231, 693),
				Vector2(1231, 694), Vector2(1230, 695), Vector2(1230, 696), Vector2(1232, 697), Vector2(1235, 698),
				Vector2(1234, 699), Vector2(1237, 700), Vector2(1238, 701), Vector2(1236, 702), Vector2(1236, 703),
				Vector2(1234, 704), Vector2(1234, 705), Vector2(1232, 706), Vector2(1234, 707), Vector2(1234, 710),
				Vector2(1235, 711), Vector2(1235, 714), Vector2(1238, 715), Vector2(1250, 718), Vector2(1250, 730),
				Vector2(1246, 731), Vector2(1250, 733), Vector2(1250, 738), Vector2(1246, 739), Vector2(1245, 740),
				Vector2(1247, 741), Vector2(1248, 742), Vector2(1248, 743), Vector2(1250, 744), Vector2(1250, 751),
				Vector2(1246, 752), Vector2(1244, 753), Vector2(1244, 754), Vector2(1243, 755), Vector2(1243, 756),
				Vector2(1247, 757), Vector2(1246, 758), Vector2(1246, 764), Vector2(1245, 765), Vector2(1245, 769),
				Vector2(1243, 770), Vector2(1243, 772), Vector2(1245, 773), Vector2(1245, 775), Vector2(1243, 776),
				Vector2(1245, 777), Vector2(1229, 781), Vector2(1228, 782), Vector2(1228, 834), Vector2(1536, 834),
				Vector2(1536, 675),
			]),
		},
		4: {
			0: PackedVector2Array([
				Vector2(0, 870), Vector2(90, 870), Vector2(90, 849), Vector2(278, 849), Vector2(278, 1024),
				Vector2(0, 1024),
			]),
		},
	}
