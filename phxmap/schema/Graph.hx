package phxmap.schema;

class Graph {
	var nextId:Int = 1;
	var definitions:Array<Definition> = [];
	var names:Map<String, Definition> = [];

	public function new() {}

	public inline function findByName<T:Definition & NamedDefinition>(name:String):T {
		return cast names.get(name);
	}

	@:generic public function find<T:Definition>(cls:Class<T>, ?base:T, ?filter:(T) -> Bool):T {
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
