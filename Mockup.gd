extends Node3D

var quad = load("res://Wall.tscn")

func get_corners(box):
	var size = box.scale
	var t = box.transform.origin
	var corners = [
		t + Vector3(size.x/2, size.y/2, size.z/2).rotated(Vector3(1, 0, 0), box.rotation.x).rotated(Vector3(0, 0, 1), box.rotation.z).rotated(Vector3(0, 1, 0), box.rotation.y),
		t + Vector3(size.x/2, size.y/2, -size.z/2).rotated(Vector3(1, 0, 0), box.rotation.x).rotated(Vector3(0, 0, 1), box.rotation.z).rotated(Vector3(0, 1, 0), box.rotation.y),
		t + Vector3(-size.x/2, size.y/2, -size.z/2).rotated(Vector3(1, 0, 0), box.rotation.x).rotated(Vector3(0, 0, 1), box.rotation.z).rotated(Vector3(0, 1, 0), box.rotation.y),
		t + Vector3(-size.x/2, size.y/2, size.z/2).rotated(Vector3(1, 0, 0), box.rotation.x).rotated(Vector3(0, 0, 1), box.rotation.z).rotated(Vector3(0, 1, 0), box.rotation.y)
	]
	return corners
	
func get_intersects(p1, p2, others):
	var intersect = []
	for m in others:
		var corners = get_corners(m)
		for i in range(4):
			var ints = Geometry2D.segment_intersects_segment(Vector2(p1.x, p1.z), Vector2(p2.x, p2.z), Vector2(corners[i].x, corners[i].z), Vector2(corners[(i+1)%4].x, corners[(i+1)%4].z))
			if ints:
				intersect.append(ints)
	intersect.sort()
	return intersect
	
func get_height(p, y, others, height):
	var mindist = height
	for m in others:
		var corners3D = get_corners(m)
		var corners = [Vector2(corners3D[0].x, corners3D[0].z), Vector2(corners3D[1].x, corners3D[1].z),Vector2(corners3D[2].x, corners3D[2].z),Vector2(corners3D[3].x, corners3D[3].z)]
		var y2 = corners3D[0].y
		if abs(y - y2) > height:
			continue
		if Geometry2D.is_point_in_polygon(p, corners):
			for p2 in corners3D:
				y2 = min(y2, p2.y)
			var dist = y2 - y
			mindist = min(dist, mindist)
	return mindist
	
func project_wall(p1, p2, others, height, texture):
	var ints = [Vector2(p1.x, p1.z)] + get_intersects(p1, p2, others) + [Vector2(p2.x, p2.z)]
	ints.sort()
	for i in range(len(ints) - 1):
		var midp = (ints[i] + ints[i+1]) / 2
		var wheight = get_height(midp, max(p1.y, p2.y), others, height)
		if wheight > 0:
			if wheight < height:
				create_wall(Vector3(ints[i].x+0.01, max(p1.y, p2.y)+height-1, ints[i].y+0.01), Vector3(ints[i+1].x+0.01, min(p1.y, p2.y)+height-1, ints[i+1].y+0.01), wheight+1, texture)
			else:
				create_wall(Vector3(ints[i].x, max(p1.y, p2.y), ints[i].y), Vector3(ints[i+1].x, min(p1.y, p2.y), ints[i+1].y), wheight, texture)
		else:
			create_wall(Vector3(ints[i].x+0.01, max(p1.y, p2.y)+wheight, ints[i].y+0.01), Vector3(ints[i+1].x+0.01, min(p1.y, p2.y)+wheight, ints[i+1].y+0.01), -wheight, texture)
		
func create_wall(p1, p2, height, texture):
	var q = quad.instantiate()
	var scale = Vector3(p1.distance_to(p2), p1.y - p2.y+height+0.001, 1)
	q.transform = q.transform.scaled(scale)
	q.transform = q.transform.rotated(Vector3(0, 1, 0), -Vector2(p1.x, p1.z).angle_to_point(Vector2(p2.x, p2.z)))
	var center = Vector3((p1.x + p2.x)/2, (p1.y + p2.y)/2+height/2, (p1.z + p2.z)/2)
	q.transform.origin = center
	for m in q.get_children():
		var tex = texture.duplicate()
		tex.uv1_scale = scale*0.1
		m.set_surface_override_material(0, tex)
	add_child(q)

func create_ceiling(mesh, height, texture):
	var q = mesh.duplicate()
	var scale = mesh.scale
	var tex = texture.duplicate()
	tex.uv1_scale = scale*0.1
	q.transform.origin += Vector3(0, height - scale.y*2, 0)
	q.set_surface_override_material(0, tex)
	add_child(q)

func _ready():
	var internal = get_node('Internal')
	var external = get_node('External')
	var HEIGHT = 15
	for meshI in internal.get_children():
		var tex = meshI.get_surface_override_material(0).duplicate()
		tex.uv1_scale = meshI.scale*0.1
		meshI.set_surface_override_material(0, tex)
		var pointsI = get_corners(meshI)
		var material = null
		var height = -999999
		for meshE in external.get_children():
			var pointsE = get_corners(meshE)
			var corners = [Vector2(pointsE[0].x, pointsE[0].z), Vector2(pointsE[1].x, pointsE[1].z),Vector2(pointsE[2].x, pointsE[2].z),Vector2(pointsE[3].x, pointsE[3].z)]
			if meshE.transform.origin.y > height and Geometry2D.is_point_in_polygon(Vector2(pointsI[0].x/2 + pointsI[2].x/2, pointsI[0].z/2 + pointsI[2].z/2), corners):
				material = meshE.get_surface_override_material(0)
		var otherI = internal.get_children()
		otherI.remove_at(otherI.find(meshI))
		var collider = StaticBody3D.new()
		var collShape = CollisionShape3D.new()
		collShape.shape = BoxShape3D.new()
		collider.add_child(collShape)
		meshI.add_child(collider)
		
		for i in range(len(pointsI)):
			project_wall(pointsI[i], pointsI[(i+1) % len(pointsI)], otherI, HEIGHT, material)
		create_ceiling(meshI, HEIGHT, material)

