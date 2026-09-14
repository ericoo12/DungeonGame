@tool
extends EditorScript

# Folders/files to skip — editor cache, import metadata, and this script itself
const IGNORE_NAMES := ["import", "godot"]
const IGNORE_EXTENSIONS := ["import", "uid"]

func _run() -> void:
	var lines: Array[String] = []
	_walk("res://", 0, lines)

	var output := "\n".join(lines)
	print(output)

	# Also write to a text file so it's easy to copy/share, not just scroll the Output panel
	var file := FileAccess.open("res://project_structure.txt", FileAccess.WRITE)
	if file:
		file.store_string(output)
		file.close()
		print("\nAlso written to res://project_structure.txt")


func _walk(path: String, depth: int, lines: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var entries: Array[String] = []
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			entries.append(name)
		name = dir.get_next()
	dir.list_dir_end()

	entries.sort()

	for entry_name in entries:
		if entry_name in IGNORE_NAMES:
			continue

		var full_path := path.path_join(entry_name)
		var indent := "  ".repeat(depth)

		if dir.current_is_dir():
			pass  # handled below via DirAccess.dir_exists check instead, see note

		if DirAccess.dir_exists_absolute(full_path):
			lines.append("%s%s/" % [indent, entry_name])
			_walk(full_path, depth + 1, lines)
		else:
			var ext := entry_name.get_extension()
			if ext in IGNORE_EXTENSIONS:
				continue
			lines.append("%s%s" % [indent, entry_name])
