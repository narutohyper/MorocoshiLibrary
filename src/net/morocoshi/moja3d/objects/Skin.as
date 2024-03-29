package net.morocoshi.moja3d.objects 
{
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;
	import net.morocoshi.common.data.DataUtil;
	import net.morocoshi.common.math.list.VectorUtil;
	import net.morocoshi.moja3d.moja3d;
	import net.morocoshi.moja3d.bounds.BoundingBox;
	import net.morocoshi.moja3d.renderer.RenderCollector;
	import net.morocoshi.moja3d.renderer.RenderPhase;
	import net.morocoshi.moja3d.resources.CombinedGeometry;
	import net.morocoshi.moja3d.resources.SkinGeometry;
	import net.morocoshi.moja3d.shaders.skin.SkinShader;
	
	use namespace moja3d;
	
	/**
	 * スキンメッシュ
	 * 
	 * @author tencho
	 */
	public class Skin extends Mesh 
	{
		moja3d var skinShaderList:Vector.<SkinShader>;
		/**メッシュ変形前の境界ボックス*/
		private var rawBounds:BoundingBox;
		/**このスキンに関連しているすべてのボーンオブジェクト。スキンシェーダー生成時に自動収集される*/
		private var usedBones:Vector.<Bone>;
		moja3d var isReady:Boolean;
		
		public function Skin() 
		{
			super();
			
			updateSeed();
			
			isReady = false;
			castShadowChildren = false;
			castLightChildren = false;
			reflectChildren = false;
			
			usedBones = new Vector.<Bone>;
			skinShaderList = new Vector.<SkinShader>;
		}
		
		override public function finaly():void 
		{
			super.finaly();
			
			DataUtil.deleteVector(skinShaderList);
			skinShaderList = null;
			rawBounds = null;
		}
		
		override public function calculateBounds():void 
		{
			super.calculateBounds();
			rawBounds = boundingBox.clone();
		}
		
		/**
		 * スキンメッシュの現在の姿勢で境界ボックスを更新する。ボーンの初期姿勢からのずれで計算するため実際のメッシュより大きく設定される傾向にあります。
		 */
		moja3d function updateSkinBounds():void
		{
			var rawMin:Vector3D = rawBounds.getMinPoint();
			var rawMax:Vector3D = rawBounds.getMaxPoint();
			var minX:Number = Number.MAX_VALUE;
			var minY:Number = Number.MAX_VALUE;
			var minZ:Number = Number.MAX_VALUE;
			var maxX:Number = -Number.MAX_VALUE;
			var maxY:Number = -Number.MAX_VALUE;
			var maxZ:Number = -Number.MAX_VALUE;
			var skinMatrix:Matrix3D = worldMatrix.clone();
			skinMatrix.invert();
			for each(var bone:Bone in usedBones)
			{
				var m:Matrix3D = bone.worldMatrix.clone();
				m.append(skinMatrix);
				m.prepend(bone.initialMatrix);
				var min:Vector3D = m.transformVector(rawMin.clone());
				var max:Vector3D = m.transformVector(rawMax.clone());
				if (minX > min.x) minX = min.x;
				if (minY > min.y) minY = min.y;
				if (minZ > min.z) minZ = min.z;
				if (minX > max.x) minX = max.x;
				if (minY > max.y) minY = max.y;
				if (minZ > max.z) minZ = max.z;
				if (maxX < min.x) maxX = min.x;
				if (maxY < min.y) maxY = min.y;
				if (maxZ < min.z) maxZ = min.z;
				if (maxX < max.x) maxX = max.x;
				if (maxY < max.y) maxY = max.y;
				if (maxZ < max.z) maxZ = max.z;
			}
			boundingBox.minX = minX;
			boundingBox.minY = minY;
			boundingBox.minZ = minZ;
			boundingBox.maxX = maxX;
			boundingBox.maxY = maxY;
			boundingBox.maxZ = maxZ;
			updateBounds();
		}
		
		override public function referenceProperties(target:Object3D):void
		{
			super.referenceProperties(target);
			
			var skin:Skin = target as Skin;
			skin.rawBounds = rawBounds? rawBounds.clone() : null;
			skin = null;
		}
		
		override public function cloneProperties(target:Object3D):void 
		{
			super.cloneProperties(target);
			
			var skin:Skin = target as Skin;
			skin.rawBounds = rawBounds? rawBounds.clone() : null;
			skin = null;
		}
		
		override public function clone():Object3D 
		{
			var skin:Skin = new Skin();
			
			cloneProperties(skin);
			
			//子を再帰的にコピーする
			var current:Object3D;
			for (current = _children; current; current = current._next)
			{
				skin.addChild(current.clone());
			}
			
			return skin;
		}
		
		override public function reference():Object3D 
		{
			var skin:Skin = new Skin();
			
			referenceProperties(skin);
			
			//子を再帰的にコピーする
			var current:Object3D;
			for (current = _children; current; current = current._next)
			{
				skin.addChild(current.reference());
			}
			
			return skin;
		}
		
		/**
		 * スキン用シェーダーを生成する
		 */
		public function createSkinShader(bones:Vector.<Bone>):void
		{
			skinShaderList.length = 0;
			usedBones.length = 0;
			
			var skinShader:SkinShader;
			var geom:SkinGeometry;
			
			if (_geometry is CombinedGeometry)
			{
				for each(geom in CombinedGeometry(_geometry).geometries)
				{
					skinShader = new SkinShader();
					skinShader.setSkinGeometry(geom);
					skinShader.initializeBones(bones, this, RenderPhase.NORMAL);
					VectorUtil.attachListDiff(usedBones, skinShader.boneList);
					skinShaderList.push(skinShader);
				}
			}
			else
			{
				skinShader = new SkinShader();
				skinShader.setSkinGeometry(_geometry as SkinGeometry);
				skinShader.initializeBones(bones, this, RenderPhase.NORMAL);
				VectorUtil.attachListDiff(usedBones, skinShader.boneList);
				skinShaderList.push(skinShader);
			}
			var combinedGeom:CombinedGeometry = geometry as CombinedGeometry;
			if (combinedGeom)
			{
				for each(var surface:Surface in surfaces)
				{
					surface.linkSurfaces(combinedSurfacesList);
				}
			}
			
			combinedGeom = null;
			skinShader = null;
			geom = null;
			
			isReady = true;
		}
		
		public function updateBoneConstants(invertMatrix:Matrix3D):void 
		{
			var item:SkinShader;
			for each (item in skinShaderList) 
			{
				item.updateBoneConstants(invertMatrix);
			}
			item = null;
		}
		
		override moja3d function collectRenderElements(collector:RenderCollector, forceCalcMatrix:Boolean, forceCalcColor:Boolean, forceCalcBounds:Boolean, worldFlip:int, mask:int):Boolean 
		{
			var result:Boolean = super.collectRenderElements(collector, forceCalcMatrix, forceCalcColor, forceCalcBounds, worldFlip, mask);
			if (parent is SkinContainer)
			{
				SkinContainer(parent).applySkinVisible(result); 
			}
			return result;
		}
		
	}

}