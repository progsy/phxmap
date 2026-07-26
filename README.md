# phxmap
Trenchbroom-compatible map loader for Haxe, forked from the [Haxe port](https://github.com/RollinBarrel/hxlibmap) of [libmap-cpp](https://github.com/EIRTeam/qodot/tree/e99e894aec5b1aea5abc9d8970ae8b364c327f2b/thirdparty/libmap_cpp/src) [(MIT License)](https://github.com/EIRTeam/qodot/blob/e99e894aec5b1aea5abc9d8970ae8b364c327f2b/LICENSE). The goal is to streamline the process of importing Quake-style maps with a handful of features and fixes.

## Integration With Frameworks
The library comes with first-class support for [Heaps](https://heaps.io). To see what it's like, check out the [sample](sample/Main.hx). It can also be used with Kha.

## Integration With Level Editors
You can define ``phxmap.fgd=[path]`` in your hxml configuration file to enable FGD generation and specify where to save the generated file. The generator will look for classes implementing phxmap.schema.Definition and write their properties (marked with @:p metadata). Check out [this](https://developer.valvesoftware.com/wiki/FGD) article to know more about FGDs. Here's an example of an entity definition written in Haxe: 
```haxe
package entity.definitions;

enum Ability {
	Immune;
	InfiniteAmmo;
	SpeedBoost;
}

enum Weapon {
	Crowbar;
	Revolver;
	Shotgun;
}

@:name("Player") @:color(100, 255, 150) @:size(-8, -8, 0, 8, 8, 56)
class PlayerDefinition extends phxmap.schema.PointDefinition {
	/** Must be greater than 0 **/
	@:p public var health:Float;
	@:p public var weapon:Weapon;
	@:p public var ammo:Int;
	@:p public var abilities:haxe.EnumFlags<Ability>;

	public function new() {
		super();
	}

	override function load(mapData:phxmap.MapData, index:Int) {
		super.load(mapData, index);
	}
}
```
This outputs the following FGD:
```
@PointClass color(100 255 150) size(-8 -8 0, 8 8 56) = Player: ""
[
	angle(float): ""
	health(float): " Must be greater than 0 "
	weapon(choices) =
	[
		1: "Crowbar"
		2: "Revolver"
		3: "Shotgun"
	]
	ammo(integer): ""
	abilities(Flags) =
	[
		4: "SpeedBoost": 0
		2: "InfiniteAmmo": 0
		1: "Immune": 0
	]
]
```
**Always** make sure to include the package(s) containing your definition classes as done [here](sample/build_hl.hxml), otherwise some classes might get omitted.