package phxmap.schema;

using StringTools;

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type.ClassType;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.TypedExprTools;

class Data {
	@:persistent public static var constructExprs:Map<String, Expr> = [];
	@:persistent public static var names:Array<String> = [];
}

class FGD {
	#if macro
	static function build(module:String, outputPath:String, overwrite:Bool = false) {
		var content:String = "";
		var types = Context.getModule(module);
		var classDefinitions:Array<String> = [];
		for (type in types) {
			switch (type) {
				case TEnum(_, _), TType(_, _):
					continue;
				default:
			}
			var cls = type.getClass();
			var followedCls:ClassType = cls;
			var definitionKind:String;

			if (cls == null) {
				continue;
			}

			var shouldBreak = false;
			while (!shouldBreak) {
				if (followedCls == null) {
					break;
				}

				if (definitionKind == null) {
					if (followedCls.name == "PointDefinition") {
						definitionKind = "PointClass";
						shouldBreak = true;
					} else if (followedCls.name == "SolidDefinition") {
						definitionKind = "SolidClass";
						shouldBreak = true;
					}
				}

				for (int in followedCls.interfaces) {
					if (int.t.get().name == "Definition") {
						if (definitionKind == null) {
							definitionKind = "baseclass";
						}
						shouldBreak = true;
						break;
					}
				}

				if (followedCls.superClass != null) {
					followedCls = followedCls.superClass.t.get();
				} else {
					shouldBreak = true;
				}
			}

			if (definitionKind == null) {
				continue;
			}

			switch (type) {
				case TInst(_.get() => t, params):
					var className:String;
					var classColor:String;
					var classSize:String;
					var classHide:Bool;
					for (m in t.meta.get()) {
						if (m.name == ":name" && m.params.length > 0) {
							className = m.params[0].getValue();
						} else if (m.name == ":color") {
							classColor = [for (p in m.params) p.toString()].join(' ');
						} else if (m.name == ":size") {
							classSize = [
								for (i in 0...m.params.length)
									i != 2 ? m.params[i].toString() : m.params[i].toString() + ","
							].join(' ');
						} else if (m.name == "hide") {
							classHide = true;
						}
					}

					if (classHide) {
						continue;
					}

					if (className == null) {
						className = t.name.replace("Definition", "");
					}

					var props:Array<String> = [];
					inline function writeProps(ct:ClassType) {
						for (f in ct.fields.get()) {
							var fgdName:String = f.name;
							var marked = false;
							var hide = false;
							for (m in f.meta.get()) {
								if (m.name == ":p") {
									marked = true;
								} else if (m.name == ":n") {
									fgdName = m.params[0].getValue();
								} else if (m.name == ":h") {
									hide = true;
								}
							}
							if (!marked || hide) {
								continue;
							}

							var fieldType = f.type;
							while (fieldType.match(TLazy(_))) {
								switch (fieldType) {
									case TLazy(_() => t):
										fieldType = t;
									default:
								}
							}

							var tbflags:Array<String> = [];
							var tbtype = switch (fieldType.toString()) {
								case "Int": "integer";
								case "Float": "float";
								case "Bool":
									tbflags.push('0: "False"');
									tbflags.push('1: "True"');
									"choices";
								default: "string";
							}

							switch (fieldType) {
								case TAbstract(_.get() => t, params):
									if (t.name == "EnumFlags") {
										var enumType:haxe.macro.Type;
										enumType = params[0];
										switch (enumType) {
											case TEnum(_.get() => t, params):
												for (c in t.constructs) {
													tbflags.push('${1 << (c.index)}: "${c.name}": 0');
												}
											default:
										}
										tbtype = "Flags";
									}
								case TEnum(_.get() => t, params):
									var tfs = [
										for (c in t.constructs) {
											{name: c.name, index: c.index};
										}
									];
									tfs.sort((a, b) -> a.index - b.index);
									for (tf in tfs) {
										tbflags.push('${tf.index + 1}: "${tf.name}"');
									}
									tbtype = "choices";
								default:
							}

							props.push('${fgdName}($tbtype)${tbflags.length > 0 ? ' =\n\t[\n\t\t${tbflags.join('\n\t\t')}\n\t]' : ''}${tbflags.length == 0 ? ': "${f.doc ?? ''}"' : ''}');
						}
					}

					if (t.superClass != null) {
						var ct = t.superClass.t.get();
						while (ct != null) {
							for (m in ct.meta.get()) {
								if (classColor == null && m.name == ":color") {
									classColor = [for (p in m.params) p.toString()].join(' ');
								} else if (classSize == null && m.name == ":size") {
									classSize = [
										for (i in 0...m.params.length)
											i != 2 ? m.params[i].toString() : m.params[i].toString() + ","
									].join(' ');
								}
							}
							writeProps(ct);
							if (ct.superClass != null) {
								ct = ct.superClass.t.get();
							} else {
								break;
							}
						}
						for (i in 0...t.interfaces.length) {
							writeProps(t.interfaces[i].t.get());
						}
					}
					writeProps(t);

					var head = '@$definitionKind${classColor != null ? ' color($classColor)' : ''}${classSize != null ? ' size($classSize)' : ''} = $className: ${t.doc ?? '""'}';
					classDefinitions.push('$head\n[\n\t${props.join("\n\t")}\n]\n');
				default:
			}
		}
		content = classDefinitions.join('\n');
		if (overwrite) {
			var o = sys.io.File.write(outputPath, false);
			o.writeString('$content');
			o.close();
		} else {
			var o = sys.io.File.append(outputPath, false);
			o.writeString('\n$content');
			o.close();
		}
	}
	#end
}

class Loader {
	#if macro
	static function build() {
		var fields = Context.getBuildFields();
		var type = Context.getLocalType();
		var complexType = type.toComplexType();
		var typePath = switch (complexType) {
			case TPath(p): p;
			default: null;
		};
		var hasConstructor = false;
		var className:String = "";
		var classGuard:Expr;
		var arraySplits:Map<String, Int> = [];

		switch (type) {
			case TInst(_.get() => t, params):
				className = t.name.replace("Definition", "");
				for (m in t.meta.get()) {
					if (m.params.length < 1) {
						continue;
					}
					if (m.name == ":name" || m.name == ":n") {
						className = m.params[0].getValue();
					} else if (m.name == ":guard" || m.name == ":g") {
						classGuard = m.params[0];
					}
				}
			default:
		};

		for (f in fields) {
			if (f.name == "new") {
				hasConstructor = true;
			} else if (f.name == "load") {
				switch (f.kind) {
					case FFun(f):
						var exprs:Array<Expr> = [];
						for (f in fields) {
							var fgdName:String = f.name;
							var marked = false;
							var arrayAccessParams:Array<Expr> = [];
							var arrayParams:Array<Expr> = [];
							var customExpr:Expr;
							var func:Expr;
							for (m in f.meta) {
								if (m.name == ":p") {
									marked = true;
								} else if (m.params.length > 0) {
									if (m.name == ":f") {
										func = m.params[0];
									} else if (m.name == ":aa") {
										arrayAccessParams = m.params;
									} else if (m.name == ":a") {
										arrayParams = m.params;
									} else if (m.name == ":c") {
										customExpr = m.params[0];
									} else if (m.name == ":n") {
										fgdName = m.params[0].getValue();
									}
								}
							}
							if (!marked && customExpr == null && arrayAccessParams.length == 0 && arrayParams.length == 0) {
								continue;
							}
							switch (f.kind) {
								case FVar(t, e), FProp(_, _, t, e):
									if (arrayAccessParams.length > 0) {
										switch (t) {
											case macro :Int:
												var splitProperty = arrayAccessParams[0].getValue();
												var arrayIndex = arraySplits.get(splitProperty) ?? 0;
												var arraySeparator = ' ';
												if (arrayAccessParams.length == 2) {
													arraySeparator = arrayAccessParams[1].getValue();
												} else if (arrayAccessParams.length > 2) {
													arraySeparator = arrayAccessParams[1].getValue();
													arrayIndex = arrayAccessParams[2].getValue();
												}

												if (!arraySplits.exists(splitProperty)) {
													arraySplits.set(splitProperty, 0);
													exprs.push(macro var $splitProperty = mapData.entities[index].properties.get($v{splitProperty})
													.split($v{arraySeparator}));
												}

												if (customExpr != null) {
													if (func == null) {
														exprs.push(macro $i{f.name} = $customExpr);
													} else {
														exprs.push(macro $i{f.name} = $func($customExpr));
													}
												} else {
													if (func == null) {
														exprs.push(macro $i{f.name} = Std.parseInt($i{splitProperty}[$v{arrayIndex}]));
													} else {
														exprs.push(macro $i{f.name} = $func(Std.parseInt($i{splitProperty}[$v{arrayIndex}])));
													}
												}
												arraySplits.set(splitProperty, arrayIndex);
											case macro :Float:
												var splitProperty = arrayAccessParams[0].getValue();
												var arrayIndex = arraySplits.get(splitProperty) ?? 0;
												var arraySeparator = ' ';
												if (arrayAccessParams.length == 2) {
													arraySeparator = arrayAccessParams[1].getValue();
												} else if (arrayAccessParams.length > 2) {
													arraySeparator = arrayAccessParams[1].getValue();
													arrayIndex = arrayAccessParams[2].getValue();
												}

												if (!arraySplits.exists(splitProperty)) {
													arraySplits.set(splitProperty, 0);
													exprs.push(macro var $splitProperty = mapData.entities[index].properties.get($v{splitProperty})
													.split($v{arraySeparator}));
												}

												if (customExpr != null) {
													if (func == null) {
														exprs.push(macro $i{f.name} = $customExpr);
													} else {
														exprs.push(macro $i{f.name} = $func($customExpr));
													}
												} else {
													if (func == null) {
														exprs.push(macro $i{f.name} = Std.parseFloat($i{splitProperty}[$v{arrayIndex}]));
													} else {
														exprs.push(macro $i{f.name} = $func(Std.parseFloat($i{splitProperty}[$v{arrayIndex}])));
													}
												}
												arraySplits.set(splitProperty, arrayIndex);
											case macro :String:
												var splitProperty = arrayAccessParams[0].getValue();
												var arrayIndex = arraySplits.get(splitProperty) ?? 0;
												var arraySeparator = ' ';
												if (arrayAccessParams.length == 2) {
													arraySeparator = arrayAccessParams[1].getValue();
												} else if (arrayAccessParams.length > 2) {
													arraySeparator = arrayAccessParams[1].getValue();
													arrayIndex = arrayAccessParams[2].getValue();
												}

												if (!arraySplits.exists(splitProperty)) {
													arraySplits.set(splitProperty, 0);
													exprs.push(macro var $splitProperty = mapData.entities[index].properties.get($v{splitProperty})
													.split($v{arraySeparator}));
												}

												if (customExpr != null) {
													if (func == null) {
														exprs.push(macro $i{f.name} = $customExpr);
													} else {
														exprs.push(macro $i{f.name} = $func($customExpr));
													}
												} else {
													if (func == null) {
														exprs.push(macro $i{f.name} = $i{splitProperty}[$v{arrayIndex}]);
													} else {
														exprs.push(macro $i{f.name} = $func($i{splitProperty}[$v{arrayIndex}]));
													}
												}
												arraySplits.set(splitProperty, arrayIndex);
											default:
										}
									} else if (arrayParams.length > 0) {
										switch (t) {
											case macro :Int:
												var splitProperty = arrayParams[0].getValue();
												var arraySeparator = ' ';
												if (arrayParams.length > 1) {
													arraySeparator = arrayParams[1].getValue();
												}

												if (!arraySplits.exists(splitProperty)) {
													arraySplits.set(splitProperty, 0);
													exprs.push(macro var $splitProperty = mapData.entities[index].properties.get($v{splitProperty})
													.split($v{arraySeparator}));
												}

												if (func == null) {
													exprs.push(macro for (s in $i{splitProperty}) {
														$i{f.name}.push(Std.parseInt(s));
													});
												} else {
													exprs.push(macro for (s in $i{splitProperty}) {
														$i{f.name}.push($func(Std.parseInt(s)));
													});
												}
											case macro :Float:
												var splitProperty = arrayParams[0].getValue();
												var arraySeparator = ' ';
												if (arrayParams.length > 1) {
													arraySeparator = arrayParams[1].getValue();
												}

												if (!arraySplits.exists(splitProperty)) {
													arraySplits.set(splitProperty, 0);
													exprs.push(macro var $splitProperty = mapData.entities[index].properties.get($v{splitProperty})
													.split($v{arraySeparator}));
												}

												if (func == null) {
													exprs.push(macro for (s in $i{splitProperty}) {
														$i{f.name}.push(Std.parseFloat(s));
													});
												} else {
													exprs.push(macro for (s in $i{splitProperty}) {
														$i{f.name}.push($func(Std.parseFloat(s)));
													});
												}
											case macro :String:
												var splitProperty = arrayParams[0].getValue();
												var arraySeparator = ' ';
												if (arrayParams.length > 1) {
													arraySeparator = arrayParams[1].getValue();
												}

												if (!arraySplits.exists(splitProperty)) {
													arraySplits.set(splitProperty, 0);
													exprs.push(macro var $splitProperty = mapData.entities[index].properties.get($v{splitProperty})
													.split($v{arraySeparator}));
												}

												if (func == null) {
													exprs.push(macro for (s in $i{splitProperty}) {
														$i{f.name}.push(s);
													});
												} else {
													exprs.push(macro for (s in $i{splitProperty}) {
														$i{f.name}.push($func(s));
													});
												}
											default:
										}
									} else {
										if (customExpr != null) {
											if (func == null) {
												exprs.push(macro $i{f.name} = $customExpr);
											} else {
												exprs.push(macro $i{f.name} = $func($customExpr));
											}
										} else {
											switch (t) {
												case macro :Int:
													if (func == null) {
														exprs.push(macro $i{f.name} = Std.parseInt(mapData.entities[index].properties.get($v{fgdName})));
													} else {
														exprs.push(macro $i{f.name} = $func(Std.parseInt(mapData.entities[index].properties.get($v{fgdName}))));
													}
												case macro :Float:
													if (func == null) {
														exprs.push(macro $i{f.name} = Std.parseFloat(mapData.entities[index].properties.get($v{fgdName})));
													} else {
														exprs.push(macro $i{f.name} = $func(Std.parseFloat(mapData.entities[index].properties.get($v{fgdName}))));
													}
												case macro :Bool:
													if (func == null) {
														exprs.push(macro $i{f.name} = Std.parseInt(mapData.entities[index].properties.get($v{fgdName})) > 0);
													} else {
														exprs.push(macro $i{f.name} = $func(Std.parseInt(mapData.entities[index].properties.get($v{fgdName}))) > 0);
													}
												case macro :String:
													if (func == null) {
														exprs.push(macro $i{f.name} = mapData.entities[index].properties.get($v{fgdName}));
													} else {
														exprs.push(macro $i{f.name} = $func(mapData.entities[index].properties.get($v{fgdName})));
													}
												case _ if (t.toString().contains("EnumFlags")):
													exprs.push(macro $i{f.name} = cast Std.parseInt(mapData.entities[index].properties.get($v{fgdName})));
												default:
													switch (t.toType()) {
														case TEnum(_.get() => t, params):
															exprs.push(macro $i{f.name} = Type.createEnumIndex($i{t.name},
																Std.parseInt(mapData.entities[index].properties.get($v{fgdName})) - 1));
														default:
													}
											}
										}
									}
								default:
							}
						}
						if (!Data.constructExprs.exists(className)) {
							if (classGuard != null) {
								Data.constructExprs.set(className, macro if (className == $v{className} && $classGuard) {
									definition = new $typePath();
								});
							} else {
								Data.constructExprs.set(className, macro if (className == $v{className}) {
									definition = new $typePath();
								});
							}
							var n = typePath.pack.length > 0 ? '${typePath.pack.join('.')}.${typePath.name}' : typePath.name;
							if (!Data.names.contains(n) && !n.startsWith("phxmap")) {
								Data.names.push(n);
							}
						}
						f.expr = macro {$b{exprs} ${f.expr}};
					default:
				}
			}
		}
		return fields;
	}
	#end
}

class Generator {
	#if macro
	static function build() {
		var fields = Context.getBuildFields();
		var exprs:Array<Expr> = [for (e in Data.constructExprs) e];

		for (f in fields) {
			switch (f.kind) {
				case FFun(fn):
					if (f.name == "generate") {
						fn.expr = macro {
							if (graph == null) {
								throw 'Graph must not be null';
								return;
							}
							graph.definitions.resize(0);
							graph.names.clear();
							${fn.expr};
							var internalIdsToIndices:Map<Int, Int> = [];
							var definitionTbGroup:Map<phxmap.schema.Definition, Int> = [];
							for (i in 0...mapData.entities.length) {
								var entity = mapData.entities[i];
								var definition:phxmap.schema.Definition = null;
								var className = entity.properties.get("classname");
								var internalName = entity.properties.get("name") ?? entity.properties.get("_tb_name");
								var internalType = entity.properties.get("_tb_type");
								var internalId = Std.parseInt(entity.properties.get("_tb_id"));
								var internalGroup = Std.parseInt(entity.properties.get("_tb_group"));
								$b{exprs};
								if (definition != null) {
									if (internalId != null) {
										internalIdsToIndices.set(internalId, graph.definitions.length);
									}
									if (internalGroup != null) {
										definitionTbGroup.set(definition, internalGroup);
									}
									var namedDefinition = Std.downcast(definition, phxmap.schema.NamedDefinition);
									if (namedDefinition != null && internalName != null) {
										if (graph.names.exists(internalName)) {
											trace('Multiple definitions have the name $internalName');
										}
										namedDefinition.name = internalName;
										graph.names.set(internalName, namedDefinition);
									}
									definition.id = graph.nextId++;
									definition.load(mapData, i);
									graph.definitions.push(definition);
								}
							}
							for (definition in graph.definitions) {
								var pointDefinition = Std.downcast(definition, phxmap.schema.PointDefinition);
								var solidDefinition = Std.downcast(definition, phxmap.schema.SolidDefinition);
								if (pointDefinition != null) {
									var group = Std.downcast(graph.definitions[internalIdsToIndices.get(definitionTbGroup.get(definition))],
										phxmap.schema.GroupDefinition);
									pointDefinition.group = group ?? pointDefinition.group;
								} else if (solidDefinition != null) {
									var group = Std.downcast(graph.definitions[internalIdsToIndices.get(definitionTbGroup.get(definition))],
										phxmap.schema.GroupDefinition);
									solidDefinition.group = group ?? solidDefinition.group;
								}
							}
						};
					}
				default:
			}
		}

		var fgdPath = Context.getDefines().get("phxmap.fgd");
		if (fgdPath != null) {
			Context.onAfterGenerate(() -> {
				for (i in 0...Data.names.length) {
					@:privateAccess FGD.build(Data.names[i], fgdPath, i == 0);
				}
			});
		}

		return fields;
	}
	#end
}
