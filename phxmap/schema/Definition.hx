package phxmap.schema;

#if !macro @:autoBuild(phxmap.schema.Macro.Loader.build()) #end
@:hide
interface Definition {
	public var id(default, null):Int;
	public var group(default, null):GroupDefinition;

	public function load(mapData:phxmap.MapData, index:Int):Void;
}
