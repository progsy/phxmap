package phxmap.schema;

typedef Geometry = {
	#if heaps
	vertices:Array<h3d.Vector>, uvs:Array<h3d.prim.UV>, normals:Array<h3d.Vector>, tangents:Array<h3d.Vector>, indices:Array<hxd.impl.UInt16>
	#elseif kha
	vertices:Array<kha.FastFloat>, uvs:Array<kha.FastFloat>, normals:Array<kha.FastFloat>, tangents:Array<kha.FastFloat>, indices:Array<Int>
	#else
	vertices:Array<Float>, uvs:Array<Float>, normals:Array<Float>, tangents:Array<Float>, indices:Array<Int>
	#end
};

@:solid @:hide
class SolidDefinition implements Definition {
	public static inline final DEFAULT_TAG:String = "default";

	public var id:Int;
	public var group:GroupDefinition;
	@:c(mapData.entities[index].center.x) @:f(Settings.scale) public var x:Float;
	@:c(mapData.entities[index].center.y) @:f(#if (heaps || phxmap.lefthanded) Settings.scaleInverse #else Settings.scale #end) public var y:Float;
	@:c(mapData.entities[index].center.z) @:f(Settings.scale) public var z:Float;
	@:p public var angle:Float;

	/**
		Each piece of geometry is associated with a determined tag.
		Use **phxmap.SolidDefinition.DEFAULT_TAG** to fetch the default geometry.
	**/
	public var geometries(default, null):Map<String, Geometry> = [];

	function new() {}

	public function load(mapData:phxmap.MapData, index:Int) {
		var indexOffsets:Map<Geometry, Int> = [];
		var entity = mapData.entities[index];
		var i = index;
		for (j in 0...entity.brushes.length) {
			var brush = entity.brushes[j];
			for (k in 0...brush.faces.length) {
				var geo = mapData.entitiesGeo[i][j][k];
				var tags = determineTags(geo.textureName, geo.contentFlags, geo.surfaceFlags);
				for (tag in tags) {
					var geometry:Geometry = geometries.get(tag);
					if (geometry == null) {
						geometry = {
							vertices: [],
							indices: [],
							uvs: [],
							normals: [],
							tangents: []
						};
						geometries.set(tag, geometry);
						indexOffsets.set(geometry, 0);
					}

					var indexOffset = indexOffsets.get(geometry);
					for (v in geo.vertices) {
						#if heaps
						geometry.vertices.push(new h3d.Vector(Settings.scale(v.vertex.x) - x, Settings.scaleInverse(v.vertex.y) - y,
							Settings.scale(v.vertex.z) - z));
						geometry.normals.push(new h3d.Vector(Settings.scale(v.normal.x), Settings.scaleInverse(v.normal.y), Settings.scale(v.normal.z)));
						geometry.tangents.push(new h3d.Vector(Settings.scale(v.tangent.x), Settings.scaleInverse(v.tangent.y), Settings.scale(v.tangent.z)));
						geometry.uvs.push(new h3d.prim.UV(v.uv.u, v.uv.v));
						#else
						geometry.vertices.push(Settings.scale(v.vertex.x) - x);
						geometry.vertices.push(#if phxmap.lefthanded Settings.scaleInverse(v.vertex.y) #else Settings.scale(v.vertex.y) #end - y);
						geometry.vertices.push(Settings.scale(v.vertex.z) - z);
						geometry.uvs.push(v.uv.u);
						geometry.uvs.push(v.uv.v);
						geometry.normals.push(v.normal.x);
						geometry.normals.push(#if phxmap.lefthanded - v.normal.y #else v.normal.y #end);
						geometry.normals.push(v.normal.z);
						geometry.tangents.push(v.tangent.x);
						geometry.tangents.push(#if phxmap.lefthanded - v.tangent.y #else v.tangent.y #end);
						geometry.tangents.push(v.tangent.z);
						#if !phxmap.no_tangent_w
						geometry.tangents.push(#if phxmap.lefthanded - v.tangent.w #else v.tangent.w #end);
						#end
						#end
					}

					var u = 0;
					while (u < (geo.vertices.length - 2) * 3) {
						geometry.indices.push(geo.indices[u] + indexOffset);
						geometry.indices.push(geo.indices[u + #if (heaps || phxmap.lefthanded) 2 #else 1 #end] + indexOffset);
						geometry.indices.push(geo.indices[u + #if (heaps || phxmap.lefthanded) 1 #else 2 #end] + indexOffset);
						u += 3;
					}
					indexOffsets.set(geometry, indexOffset + geo.vertices.length);
				}
			}
		}
	}

	/**
		This is meant to be overriden to specify geometry tags based on texture name, content flags and surface flags.
	**/
	public static dynamic function determineTags(textureName:String, contentFlags:Int, surfaceFlags:Int):Array<String> {
		return [DEFAULT_TAG];
	}

	#if heaps
	public var primitiveCache:Map<String, h3d.prim.Polygon> = [];
	public var colliderCache:Map<String, h3d.col.Polygon> = [];

	public function getPrimitive(tag:String = DEFAULT_TAG):Null<h3d.prim.Polygon> {
		var primitive = primitiveCache.get(tag);
		if (primitive == null) {
			var geometry = geometries.get(tag);
			if (geometry == null || geometry.vertices.length == 0) {
				return primitive;
			}

			primitive = new h3d.prim.Polygon(geometry.vertices, cast geometry.indices);
			primitive.uvs = geometry.uvs;
			primitive.normals = geometry.normals;
			primitive.tangents = geometry.tangents;
			primitiveCache.set(tag, primitive);
		}
		return primitive;
	}

	public function getCollider(tag:String = DEFAULT_TAG):Null<h3d.col.Polygon> @:privateAccess {
		var collider = colliderCache.get(tag);
		if (collider == null) {
			var geometry = geometries.get(tag);
			if (geometry == null || geometry.vertices.length == 0) {
				return collider;
			}
			var primitive = primitiveCache.get(tag);
			if (primitive == null) {
				var indices:Array<Int> = [];
				var vertices:Array<hxd.impl.Float32> = [];
				vertices.resize(geometry.vertices.length * 3);
				indices.resize(geometry.indices.length);
				for (i in 0...geometry.indices.length) {
					indices[i] = geometry.indices[i];
				}
				var i = 0;
				for (v in geometry.vertices) {
					vertices[i++] = v.x;
					vertices[i++] = v.y;
					vertices[i++] = v.z;
				}
				collider = new h3d.col.Polygon();
				collider.addBuffers(cast vertices, cast indices);
			} else {
				collider = cast primitive.getCollider();
			}
			colliderCache.set(tag, collider);
		}
		return collider;
	}
	#end
}
