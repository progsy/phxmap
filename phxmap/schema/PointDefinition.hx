package phxmap.schema;

@:point @:hide
class PointDefinition implements Definition {
	public var id:Int;
	public var group:GroupDefinition;
	@:aa("origin", ' ', 0) @:f(Settings.scale) public var x:Float;
	@:aa("origin", ' ', 1) @:f(#if (heaps || phxmap.lefthanded) Settings.scaleInverse #else Settings.scale #end) public var y:Float;
	@:aa("origin", ' ', 2) @:f(Settings.scale) public var z:Float;
	@:p public var angle:Float;

	function new() {}

	public function load(mapData:phxmap.MapData, index:Int) {}
}
