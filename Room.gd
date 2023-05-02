extends Control

var points
var floortex
var walltex

func _draw():
	draw_colored_polygon(points, Color(.5,.0,.0), PackedVector2Array(), floortex)
