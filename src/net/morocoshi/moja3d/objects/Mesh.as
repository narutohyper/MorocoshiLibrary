package net.morocoshi.moja3d.objects 
{
	import flash.geom.Matrix3D;
	import net.morocoshi.common.data.DataUtil;
	import net.morocoshi.moja3d.moja3d;
	import net.morocoshi.moja3d.bounds.BoundingBox;
	import net.morocoshi.moja3d.collision.CollisionMesh;
	import net.morocoshi.moja3d.collision.CollisionRay;
	import net.morocoshi.moja3d.materials.Material;
	import net.morocoshi.moja3d.materials.TriangleFace;
	import net.morocoshi.moja3d.renderer.RenderCollector;
	import net.morocoshi.moja3d.renderer.RenderElement;
	import net.morocoshi.moja3d.renderer.RenderLayer;
	import net.morocoshi.moja3d.renderer.RenderPhase;
	import net.morocoshi.moja3d.resources.CombinedGeometry;
	import net.morocoshi.moja3d.resources.Geometry;
	import net.morocoshi.moja3d.resources.Resource;
	import net.morocoshi.moja3d.shaders.MaterialShader;
	import net.morocoshi.moja3d.shaders.ShaderList;
	import net.morocoshi.moja3d.shaders.outline.OutlineColorShader;
	import net.morocoshi.moja3d.shaders.render.ZBiasShader;
	
	use namespace moja3d;
	
	/**
	 * ポリゴンメッシュオブジェクト
	 * 
	 * @author tencho
	 */
	public class Mesh extends Object3D
	{
		/**描画するレイヤー。RenderLayer参照*/
		public var layer:uint;
		/**サーフェイスリスト*/
		public var surfaces:Vector.<Surface>;
		moja3d var combinedSurfacesList:Vector.<Vector.<Surface>>;
		/*
			[BasicShader]//basicShader
			Mesh.beforeMatrixShaderList
			[ModelTransformShader]
			Mesh.startShaderList
			[Skin.skinShader]
			Material.shaderList
			Mesh.endShaderList
			[AGALCache.viewShaderList]
			Mesh.afterViewShaderList
			Mesh.colorTransformShader
			Mesh.zBiasShader
			[EndShader]//lastShader
		*/
		public var basicShader:MaterialShader;
		public var beforeMatrixShaderList:ShaderList;
		public var startShaderList:ShaderList;
		public var endShaderList:ShaderList;
		public var afterViewShaderList:ShaderList;
		public var zBiasShader:ZBiasShader;
		public var lastShader:MaterialShader;
		
		public var mouseDoubleSided:Boolean;
		moja3d var outlineShader:OutlineColorShader;
		moja3d var _outlineEnabled:Boolean;
		
		private var _key:String;
		private var _zbias:Number;
		private var _renderable:Boolean;
		moja3d var _geometry:Geometry;
		
		/**RenderElementインスタンスのキャッシュ（new回数を抑える用）*/
		private var renderElements:Vector.<RenderElement>;
		private var elementCount:int;
		
		static moja3d var globalSeed:int;
		moja3d var seed:String;
		
		public function Mesh() 
		{
			super();
			
			updateSeed();
			_zbias = 0;
			_renderable = true;
			mouseDoubleSided = false;
			layer = RenderLayer.OPAQUE;
			_geometry = new Geometry();
			surfaces = new Vector.<Surface>;
			renderElements = new Vector.<RenderElement>;
			zBiasShader = new ZBiasShader(_zbias);
			startShaderList = null;
			endShaderList = null;
		}
		
		public function updateSeed():void
		{
			seed = String(++globalSeed);
		}
		
		public function get geometry():Geometry 
		{
			return _geometry;
		}
		
		public function set geometry(value:Geometry):void 
		{
			_geometry = value;
		}
		
		public function get zbias():Number 
		{
			return _zbias;
		}
		
		public function set zbias(value:Number):void 
		{
			zBiasShader.zbias = _zbias = value;
			zBiasShader.enabled = (_zbias != 0);
		}
		
		public function get renderable():Boolean 
		{
			return _renderable;
		}
		
		public function set renderable(value:Boolean):void 
		{
			_renderable = value;
		}
		
		/**
		 * TODO: ここをどうするか考える
		 */
		public function get key():String 
		{
			return seed + "_" + (colorTransformShader? colorTransformShader.alphaTransform : "A") + "_";
		}
		
		override public function clone():Object3D 
		{
			var mesh:Mesh = new Mesh();
			cloneProperties(mesh);
			//子を再帰的にコピーする
			var current:Object3D;
			for (current = _children; current; current = current._next)
			{
				mesh.addChild(current.clone());
			}
			return mesh;
		}
		
		/**
		 * 境界ボックスを包む境界球を計算するための下準備をする。
		 * この処理はジオメトリを生成した直後か、ジオメトリが変形した時に呼び出します。
		 * 全頂点を包む境界ボックスを求めるので負荷に注意。
		 */
		override public function calculateBounds():void 
		{
			if (boundingBox == null)
			{
				boundingBox = new BoundingBox();
			}
			geometry.calculateBounds(boundingBox);
			boundingBox.updateCenterPoint();
			calculateBoundingOrder = true;
		}
		
		/**
		 * 全ポリゴンに指定のマテリアルを貼る。サーフェイスはリセットされて1つになる。
		 * @param	material
		 */
		public function setMaterialToAllSurfaces(material:Material):void
		{
			surfaces.length = 0;
			surfaces.push(new Surface(material, 0, _geometry.vertexIndices.length / 3));
		}
		
		/**
		 * Meshをコピーするが、GeometryとMaterialはインスタンスを共有する
		 * @return
		 */
		override public function reference():Object3D 
		{
			var mesh:Mesh = new Mesh();
			referenceProperties(mesh);
			//子を再帰的にコピーする
			var current:Object3D;
			for (current = _children; current; current = current._next)
			{
				mesh.addChild(current.reference());
			}
			return mesh;
		}
		
		override public function clear(hierarchy:Boolean, force:Boolean = false):void 
		{
			if (surfaces)
			{
				var surface:Surface;
				for each(surface in surfaces)
				{
					if (surface._material)
					{
						surface._material.clear(force);
					}
				}
				surface = null;
			}
			
			super.clear(hierarchy, force);
		}
		
		override public function finaly():void 
		{
			super.finaly();
			
			layer = 0;
			var surface:Surface;
			if (surfaces)
			{
				for each(surface in surfaces)
				{
					surface.finaly();
				}
				DataUtil.deleteVector(surfaces);
				surfaces = null;
			}
			if (combinedSurfacesList)
			{
				for each(var surfaceList:Vector.<Surface> in combinedSurfacesList)
				{
					if (surfaceList)
					{
						for each(surface in surfaceList)
						{
							surface.finaly();
						}
						DataUtil.deleteVector(surfaceList);
						surfaceList = null;
					}
				}
				DataUtil.deleteVector(combinedSurfacesList);
				combinedSurfacesList = null;
			}
			surface = null;
			
			if (startShaderList)
			{
				startShaderList.finaly();
				startShaderList = null;
			}
			if (endShaderList)
			{
				endShaderList.finaly();
				endShaderList = null;
			}
			if (afterViewShaderList)
			{
				afterViewShaderList.finaly();
				afterViewShaderList = null;
			}
			if (beforeMatrixShaderList)
			{
				beforeMatrixShaderList.finaly();
				beforeMatrixShaderList = null;
			}
			
			basicShader = null;
			lastShader = null;
			zBiasShader = null;
			_geometry = null;
			_key = null;
			seed = null;
			
			if (renderElements)
			{
				var element:RenderElement;
				for each(element in renderElements)
				{
					element.finaly();
				}
				element = null;
				DataUtil.deleteVector(renderElements);
				renderElements = null;
			}
			
			elementCount = 0;
			_zbias = 0;
		}
		
		/**
		 * サーフェイス情報と、集合ジオメトリ用のサーフェイス情報を参照コピー（階層は複製）
		 * @param	mesh
		 */
		private function referenceSurfaces(mesh:Mesh):void
		{
			var i:int;
			var j:int;
			var n:int;
			var m:int;
			var surface:Surface;
			
			n = surfaces.length;
			for (i = 0; i < n; i++) 
			{
				surface = new Surface(surfaces[i]._material);
				surface.numTriangles = surfaces[i].numTriangles;
				surface.firstIndex = surfaces[i].firstIndex;
				mesh.surfaces.push(surface);
			}
			
			surface = null;
			if (combinedSurfacesList == null) return;
			
			var combinedSurfaces:Vector.<Surface>;
			mesh.combinedSurfacesList = new Vector.<Vector.<Surface>>;
			n = combinedSurfacesList.length;		
			for (i = 0; i < n; i++) 
			{
				combinedSurfaces = new Vector.<Surface>;
				mesh.combinedSurfacesList.push(combinedSurfaces);
				m = combinedSurfacesList[i].length;
				for (j = 0; j < m; j++)
				{
					surface = new Surface(combinedSurfacesList[i][j]._material);
					surface.numTriangles = combinedSurfacesList[i][j].numTriangles;
					surface.firstIndex = combinedSurfacesList[i][j].firstIndex;
					combinedSurfaces.push(surface);
				}
			}
			
			surface = null;
			combinedSurfaces = null;
		}
		
		override public function referenceProperties(target:Object3D):void
		{
			super.referenceProperties(target);
			
			var mesh:Mesh = target as Mesh;
			mesh.zbias = _zbias;
			mesh.geometry = geometry;
			
			referenceSurfaces(mesh);
		}
		
		override public function cloneProperties(target:Object3D):void 
		{
			super.cloneProperties(target);
			
			var mesh:Mesh = target as Mesh;
			mesh.zbias = _zbias;
			mesh.geometry = geometry.clone() as Geometry;
			
			referenceSurfaces(mesh);
		}
		
		override public function getResources(hierarchy:Boolean, filter:Class = null):Vector.<Resource> 
		{
			if (filter == null)
			{
				filter = Resource;
			}
			
			var material:Material;
			var geometryItem:Geometry;
			var resourceList:Vector.<Resource>;
			var resource:Resource;
			
			var result:Vector.<Resource> = super.getResources(hierarchy, filter);
			
			if (_geometry)
			{
				if (_geometry is CombinedGeometry)
				{
					for each(geometryItem in CombinedGeometry(_geometry).geometries)
					{
						if (geometryItem is filter) result.push(geometryItem);
					}
				}
				else if (_geometry is filter)
				{
					result.push(_geometry);
				}
			}
			
			var n:int = surfaces.length;
			for (var i:int = 0; i < n; i++) 
			{
				material = surfaces[i]._material;
				if (material)
				{
					resourceList = material.getResources();
					var numResource:int = resourceList.length;
					for (var j:int = 0; j < numResource; j++) 
					{
						resource = resourceList[j];
						if (resource is filter)
						{
							result.push(resource);
						}
					}
				}
			}
			
			resourceList = null;
			geometryItem = null;
			resource = null;
			material = null;
			
			return result;
		}
		
		private function getOutlineShader():OutlineColorShader
		{
			return outlineShader || (outlineShader = new OutlineColorShader());
		}
		
		/**
		 * ポリゴンベースのアウトラインを設定する
		 * @param	enabled		表示するか
		 * @param	thickness	厚さ
		 * @param	color		色
		 * @param	alpha		不透明度
		 * @param	fixed		厚さがカメラ距離に関係なく一定
		 */
		public function setOutline(enabled:Boolean, thickness:Number = 1, color:uint = 0x000000, alpha:Number = 1, fixed:Boolean = true):void
		{
			_outlineEnabled = enabled;
			var shader:OutlineColorShader = getOutlineShader();
			shader.thickness = thickness;
			shader.color = color;
			shader.alpha = alpha;
			shader.fixed = fixed;
		}
		/**
		 * ポリゴンベースのアウトラインを表示するか
		 */
		public function set outlineEnabled(value:Boolean):void
		{
			_outlineEnabled = value;
			if (_outlineEnabled)
			{
				getOutlineShader();
			}
		}
		public function get outlineEnabled():Boolean
		{
			return _outlineEnabled;
		}
		
		/**
		 * ポリゴンベースのアウトラインの厚さ
		 */
		public function set outlineThickness(value:Number):void
		{
			getOutlineShader().thickness = value;
		}
		public function get outlineThickness():Number
		{
			return getOutlineShader().thickness;
		}
		
		/**
		 * ポリゴンベースのアウトラインの厚さがカメラ距離に関係なく一定になるか
		 */
		public function set outlineFixed(value:Boolean):void
		{
			getOutlineShader().fixed = value;
		}
		public function get outlineFixed():Boolean
		{
			return getOutlineShader().fixed;
		}
		
		/**
		 * ポリゴンベースのアウトラインの色
		 */
		public function set outlineColor(value:uint):void
		{
			getOutlineShader().color = value;
		}
		public function get outlineColor():uint
		{
			return getOutlineShader().color;
		}
		
		/**
		 * ポリゴンベースのアウトラインの不透明度
		 */
		public function set outlineAlpha(value:Number):void
		{
			getOutlineShader().alpha = value;
		}
		public function get outlineAlpha():Number
		{
			return getOutlineShader().alpha;
		}
		
		override moja3d function collectRenderElements(collector:RenderCollector, forceCalcMatrix:Boolean, forceCalcColor:Boolean, forceCalcBounds:Boolean, worldFlip:int, mask:int):Boolean 
		{
			var success:Boolean = super.collectRenderElements(collector, forceCalcMatrix, forceCalcColor, forceCalcBounds, worldFlip, mask);
			
			if (success == false)
			{
				return false;
			}
			
			var combined:CombinedGeometry = _geometry as CombinedGeometry;
			
			//単体ジオメトリで、未ロードの場合
			if (combined == null && _geometry.isUploaded == false) return false;
			//混合ジオメトリで、どれか1つでも未ロードだった場合
			if (combined)
			{
				var nn:int = combined.geometries.length;
				for (var ii:int = 0; ii < nn; ii++) 
				{
					if (combined.geometries[ii].isUploaded == false)
					{
						combined = null;
						return false;
					}
				}
			}
			
			if (_renderable == false) return true;
			
			elementCount = -1;
			
			var skin:Skin = this as Skin;
			var skinShader:MaterialShader;
			if (combined)
			{
				var n:int = combined.geometries.length;
				for (var i:int = 0; i < n; i++) 
				{
					skinShader = (skin && skin.isReady)? skin.skinShaderList[i] : null;
					if (!collectSurfaces(collector, combinedSurfacesList[i], combined.geometries[i], mask, worldFlip, skinShader))
					{
						combined = null;
						skinShader = null;
						return false;
					}
					//トゥーンレンダリングのアウトライン
					if (collector.renderPhase == RenderPhase.NORMAL && _outlineEnabled)
					{
						collector.renderPhase = RenderPhase.OUTLINE;
						collector.materialCulling = TriangleFace.BACK;
						collector.outlineShader = outlineShader;
						collectSurfaces(collector, combinedSurfacesList[i], combined.geometries[i], mask, worldFlip, skinShader);
						collector.renderPhase = RenderPhase.NORMAL;
						collector.materialCulling = null;
						collector.outlineShader = null;
					}
				}
			}
			else
			{
				skinShader = (skin && skin.isReady)? skin.skinShaderList[0] : null;
				if (!collectSurfaces(collector, surfaces, _geometry, mask, worldFlip, skinShader))
				{
					combined = null;
					skinShader = null;
					return false;
				}
				//トゥーンレンダリングのアウトライン
				if (collector.renderPhase == RenderPhase.NORMAL && _outlineEnabled)
				{
					collector.renderPhase = RenderPhase.OUTLINE;
					collector.materialCulling = TriangleFace.BACK;
					collector.outlineShader = outlineShader;
					collectSurfaces(collector, surfaces, _geometry, mask, worldFlip, skinShader)
					collector.renderPhase = RenderPhase.NORMAL;
					collector.materialCulling = null;
					collector.outlineShader = null;
				}
			}
			
			combined = null;
			skinShader = null;
			
			return true;
		}
		
		private function collectSurfaces(collector:RenderCollector, surfaceList:Vector.<Surface>, geom:Geometry, mask:int, worldFlip:int, skinShader:MaterialShader):Boolean 
		{
			var surface:Surface;
			var material:Material;
			var checkShader:ShaderList;
			var shaderList:ShaderList;
			var element:RenderElement;
			
			//サーフェイスの数繰り返す
			var n:int = surfaceList.length;
			for (var i:int = 0; i < n; i++) 
			{
				surface = surfaceList[i];
				material = surface._material;
				//マテリアルが貼られていない、もしくはポリゴンが無ければスキップ
				if (material == null || surface.numTriangles == 0) continue;
				
				//シェーダー情報の収集
				material.collectShaderList(collector, this, geom, skinShader);
				
				//反射フェーズの場合にマテリアルに反射シェーダーがあれば終了？continueでない理由は？
				if (collector.renderPhase == RenderPhase.REFLECT && material.shaderList.reflectShader)
				{
					return false;
				}
				
				//チェックフェーズの場合に反射や影などのシェーダーをチェックする。レンダリング要素はマスク以外追加しないで終了
				var checkMode:Boolean = (collector.renderPhase == RenderPhase.CHECK);
				if (checkMode)
				{
					//反射要素があれば収集するが、カメラが無い＝preloadPrograms時はスキップする
					checkShader = collector.opaquePassShaderList || collector.alphaPassShaderList;
					if (checkShader && checkShader.reflectShader)
					{
						if (collector.camera)
						{
							collector.addReflectElement(_worldMatrix.position.z, checkShader.reflectShader);
						}
						else
						{
							collector.reflectiveWater.hasReflectElement = true;
						}
					}
					var hasShadow1:Boolean = (material.shaderList.shadowShader && material.shaderList.shadowShader.enabled);
					var hasShadow2:Boolean = (startShaderList && startShaderList.shadowShader && startShaderList.shadowShader.enabled);
					var hasShadow3:Boolean = (endShaderList && endShaderList.shadowShader && endShaderList.shadowShader.enabled);
					if (hasShadow1 || hasShadow2 || hasShadow3)
					{
						collector.hasShadowElement = true;
					}
					if (material.shaderList.lightShader)
					{
						collector.hasLightElement = true;
					}
					//マスクがあれば追加する
					if (collector.existMaskFilter && (mask != -1 || renderMask != -1))
					{
						var maskColor:uint = ((mask == -1)? 0 : mask) | ((renderMask == -1)? 0 : renderMask);
						collector.hasMaskElement = true;
						material.collectMaskShaderList(collector, this, geom, maskColor, skinShader);
					}
					else
					{
						continue;
					}
				}
				
				//不透明要素＆半透明要素をそれぞれレンダリング要素として収集する
				for (var j:int = 0; j < 2; j++) 
				{
					shaderList = (j == 0)? collector.opaquePassShaderList : collector.alphaPassShaderList;
					if (shaderList == null) continue;
					
					elementCount++;
					var shaderLayer:uint = (j == 0)? RenderLayer.OPAQUE : RenderLayer.TRANSPARENT;
					element = (renderElements.length > elementCount)? renderElements[elementCount] : null;
					if (element == null)
					{
						element = renderElements[elementCount] = new RenderElement();
					}
					//element.name = String(this) + geom.indexBuffer;
					element.firstIndex = surface.firstIndex;
					element.numTriangles = surface.numTriangles;
					element.matrix = _worldMatrix;
					element.vertexBufferFormatList = geom.vertexBufferFormatList;
					element.vertexBufferList = geom.vertexBufferList;
					element.indexBuffer = geom.indexBuffer;
					element.culling = collector.materialCulling || material.culling;
					element.sourceFactor = material.sourceFactor;
					element.destinationFactor = material.destinationFactor;
					//マイナススケールでフリップしていた場合は表示を反転する
					if (worldFlip * flip == -1)
					{
						if (element.culling == TriangleFace.FRONT) element.culling = TriangleFace.BACK;
						else if (element.culling == TriangleFace.BACK) element.culling = TriangleFace.FRONT;
					}
					element.shaderList = shaderList;
					element.layer = layer | surface.layer | shaderLayer;
					element.sortPriority = sortPriority;
					
					collector.addRenderElement(element);
				}
				
			}
			
			surface = null;
			material = null;
			checkShader = null;
			shaderList = null;
			element = null;
			
			return true;
		}
		
		override public function intersectRay(ray:CollisionRay):Boolean 
		{
			if (super.intersectRay(ray) == false) return false;
			if (boundingBox == null || _inCameraView == false || mouseEnabled == false) return false;
			if (ray.hitToBall(boundingBox) == false) return false;
			
			var w:Matrix3D = worldMatrix.clone();
			w.invert();
			ray.start2 = w.transformVector(ray.start);
			ray.normal2 = w.deltaTransformVector(ray.normal);
			ray.distance2 = ray.normal2.length * ray.distance;
			ray.normal2.normalize();
			
			if (_geometry)
			{
				if (_geometry.collision == null)
				{
					_geometry.collision = new CollisionMesh();
					_geometry.collision.parse(_geometry);
				}
				_geometry.collision.getHitData(ray, mouseDoubleSided, this);
			}
			
			return true;
		}
		
	}

}