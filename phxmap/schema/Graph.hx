package phxmap.schema;

class Graph {
	var definitions:Map<Int, Definition> = [];
	var groups:Map<String, GroupDefinition> = [];

	public function new() {}

	public inline function getDefinition(id:Int):Null<Definition> {
		return definitions.get(id);
	}

	public inline function getGroupDefinition(name:String):Null<GroupDefinition> {
		return groups.get(name);
	}

	@:generic public function find<T:Definition>(cls:Class<T>, ?filter:(T) -> Bool):T {
		var definition:T = null;
		if (filter == null) {
			for (d in definitions) {
				var td = Std.downcast(d, cls);
				if (td != null) {
					definition = td;
					break;
				}
			}
		} else {
			for (d in definitions) {
				var td = Std.downcast(d, cls);
				if (td != null) {
					if (filter(td)) {
						definition = td;
					}
				}
			}
		}
		return definition;
	}

	@:generic public function findAll<T:Definition>(cls:Class<T>, ?filter:(T) -> Bool, ?base:Array<T>):Array<T> {
		var array = base ?? [];
		if (filter == null) {
			for (d in definitions) {
				var td = Std.downcast(d, cls);
				if (td != null) {
					array.push(td);
				}
			}
		} else {
			for (d in definitions) {
				var td = Std.downcast(d, cls);
				if (td != null) {
					if (filter(td)) {
						array.push(td);
					}
				}
			}
		}
		return array;
	}
}
