package phxmap.schema;

#if !macro @:autoBuild(phxmap.schema.Macro.Loader.build()) #end
@:hide
interface Definition {
	public var group:GroupDefinition;

	public function load(mapData:phxmap.MapData, index:Int):Void;
}
