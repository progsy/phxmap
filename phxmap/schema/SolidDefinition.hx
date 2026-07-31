package phxmap.schema;

typedef Geometry = {
	#if heaps
	positions:Array<hxd.impl.Float32>, uvs:Array<hxd.impl.Float32>, normals:Array<hxd.impl.Float32>, tangents:Array<hxd.impl.Float32>,
	indices:Array<hxd.impl.UInt16>,
	#elseif kha
	positions:Array<kha.FastFloat>, uvs:Array<kha.FastFloat>, normals:Array<kha.FastFloat>, tangents:Array<kha.FastFloat>, indices:Array<Int>,
	#else
	positions:Array<Float>, uvs:Array<Float>, normals:Array<Float>, tangents:Array<Float>, indices:Array<Int>,
	#end
	textureSet:Int // when the N-th bit is set to 1, it means this geometry uses texture index N from textureNames
};

@:solid @:hide
class SolidDefinition implements Definition {
	public static inline final DEFAULT_TAG:String = "default";

	public var id(default, null):Int;
	public var group(default, null):GroupDefinition;
	@:c(mapData.entities[index].center.x) @:f(Settings.scale) public var x:Float;
	@:c(mapData.entities[index].center.y) @:f(#if (heaps || phxmap.lefthanded) Settings.scaleInverse #else Settings.scale #end) public var y:Float;
	@:c(mapData.entities[index].center.z) @:f(Settings.scale) public var z:Float;
	@:p public var angle:Float;

	/**
		Each piece of geometry is associated with a determined tag.
		Use **phxmap.SolidDefinition.DEFAULT_TAG** to fetch the default geometry.
	**/
	public var geometries(default, null):Map<String, Geometry> = [];

	public var textureNames(default, null):Array<String> = [];

	function new() {}

	public function load(mapData:phxmap.MapData, index:Int) {
		var indexOffsets:Map<Geometry, Int> = [];
		for (geometry in geometries) {
			geometry.positions.resize(0);
			geometry.normals.resize(0);
			geometry.tangents.resize(0);
			geometry.uvs.resize(0);
			geometry.indices.resize(0);
			indexOffsets.set(geometry, 0);
		}
		var entity = mapData.entities[index];
		var i = index;
		for (j in 0...entity.brushes.length) {
			var brush = entity.brushes[j];
			for (k in 0...brush.faces.length) {
				var geo = mapData.entitiesGeo[i][j][k];
				var tags = determineTags(geo.textureName, geo.contentFlags, geo.surfaceFlags);
				var textureIndex = textureNames.indexOf(geo.textureName);
				if (textureIndex == -1) {
					textureIndex = textureNames.length;
					textureNames.push(geo.textureName);
				}
				for (tag in tags) {
					var geometry:Geometry = geometries.get(tag);
					if (geometry == null) {
						geometry = {
							positions: [],
							normals: [],
							tangents: [],
							uvs: [],
							indices: [],
							textureSet: 0
						};
						geometries.set(tag, geometry);
						indexOffsets.set(geometry, 0);
					}
					geometry.textureSet = (geometry.textureSet & ~(1 << textureIndex)) | (1 << textureIndex);

					var indexOffset = indexOffsets.get(geometry);
					for (v in geo.vertices) {
						geometry.positions.push(Settings.scale(v.vertex.x) - x);
						geometry.positions.push(#if (heaps || phxmap.lefthanded) Settings.scaleInverse(v.vertex.y) #else Settings.scale(v.vertex.y) #end - y);
						geometry.positions.push(Settings.scale(v.vertex.z) - z);
						geometry.normals.push(v.normal.x);
						geometry.normals.push(#if (heaps || phxmap.lefthanded) -v.normal.y #else v.normal.y #end);
						geometry.normals.push(v.normal.z);
						geometry.tangents.push(v.tangent.x);
						geometry.tangents.push(#if (heaps || phxmap.lefthanded) -v.tangent.y #else v.tangent.y #end);
						geometry.tangents.push(v.tangent.z);
						#if phxmap.tangent_w
						geometry.tangents.push(#if (heaps || phxmap.lefthanded) -v.tangent.w #else v.tangent.w #end);
						#end
						geometry.uvs.push(v.uv.u);
						geometry.uvs.push(v.uv.v);
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
	public var primitiveCache:Map<String, h3d.prim.RawPrimitive> = [];
	public var colliderCache:Map<String, h3d.col.Polygon> = [];

	public function getPrimitive(tag:String = DEFAULT_TAG):Null<h3d.prim.RawPrimitive> {
		var primitive = primitiveCache.get(tag);
		if (primitive == null) {
			var geometry = geometries.get(tag);
			if (geometry == null || geometry.positions.length == 0) {
				return primitive;
			}

			var format = @:privateAccess new hxd.BufferFormat([
				{name: 'position', type: DVec3, precision: F32},
				{name: 'normal', type: DVec3, precision: F32},
				{name: 'tangent', type: DVec3, precision: F32},
				{name: 'uv', type: DVec2, precision: F16}
			]);
			var cluster = new hxd.FloatBuffer(geometry.positions.length + geometry.normals.length + geometry.tangents.length + geometry.uvs.length);
			var i = 0;
			var j = 0;
			var k = 0;
			var minX = 0.0;
			var minY = 0.0;
			var minZ = 0.0;
			var maxX = 0.0;
			var maxY = 0.0;
			var maxZ = 0.0;
			while (i < cluster.length) {
				if (geometry.positions[j] < minX) {
					minX = geometry.positions[j];
				} else if (geometry.positions[j] > maxX) {
					maxX = geometry.positions[j];
				}
				if (geometry.positions[j + 1] < minY) {
					minY = geometry.positions[j + 1];
				} else if (geometry.positions[j + 1] > maxY) {
					maxY = geometry.positions[j + 1];
				}
				if (geometry.positions[j + 2] < minZ) {
					minZ = geometry.positions[j + 2];
				} else if (geometry.positions[j + 2] > maxZ) {
					maxZ = geometry.positions[j + 2];
				}
				cluster[i++] = geometry.positions[j];
				cluster[i++] = geometry.positions[j + 1];
				cluster[i++] = geometry.positions[j + 2];
				cluster[i++] = geometry.normals[j];
				cluster[i++] = geometry.normals[j + 1];
				cluster[i++] = geometry.normals[j + 2];
				cluster[i++] = geometry.tangents[j++];
				cluster[i++] = geometry.tangents[j++];
				cluster[i++] = geometry.tangents[j++];
				cluster[i++] = geometry.uvs[k++];
				cluster[i++] = geometry.uvs[k++];
			}
			var bounds = new h3d.col.Bounds();
			bounds.xMin = minX;
			bounds.yMin = minY;
			bounds.zMin = minZ;
			bounds.xMax = maxX;
			bounds.yMax = maxY;
			bounds.zMax = maxZ;
			primitive = new h3d.prim.RawPrimitive({
				vbuf: cluster,
				ibuf: cast geometry.indices,
				format: format,
				bounds: bounds
			});
			primitiveCache.set(tag, primitive);
		}
		return primitive;
	}

	public function getCollider(tag:String = DEFAULT_TAG):Null<h3d.col.Polygon> @:privateAccess {
		var collider = colliderCache.get(tag);
		if (collider == null) {
			var geometry = geometries.get(tag);
			if (geometry == null || geometry.positions.length == 0) {
				return collider;
			}
			collider = new h3d.col.Polygon();
			@:privateAccess for (i in 0...Std.int(geometry.indices.length / 3)) {
				var k = i * 3;
				var t = new h3d.col.Polygon.TriPlane(collider.oriented);

				var i0 = geometry.indices[k] * 3;
				var i1 = geometry.indices[k + 1] * 3;
				var i2 = geometry.indices[k + 2] * 3;

				t.init(new h3d.Vector(geometry.positions[i0], geometry.positions[i0 + 1], geometry.positions[i0 + 2]),
					new h3d.Vector(geometry.positions[i1], geometry.positions[i1 + 1], geometry.positions[i1 + 2]),
					new h3d.Vector(geometry.positions[i2], geometry.positions[i2 + 1], geometry.positions[i2 + 2]));

				t.next = collider.triPlanes;
				collider.triPlanes = t;
			}
			colliderCache.set(tag, collider);
		}
		return collider;
	}
	#end
}
