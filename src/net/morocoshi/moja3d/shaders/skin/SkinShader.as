package net.morocoshi.moja3d.shaders.skin 
{
	import flash.geom.Matrix3D;
	import net.morocoshi.moja3d.agal.AGALConstant;
	import net.morocoshi.moja3d.moja3d;
	import net.morocoshi.moja3d.objects.Bone;
	import net.morocoshi.moja3d.objects.Skin;
	import net.morocoshi.moja3d.renderer.RenderPhase;
	import net.morocoshi.moja3d.resources.Geometry;
	import net.morocoshi.moja3d.resources.VertexAttribute;
	import net.morocoshi.moja3d.shaders.AlphaMode;
	import net.morocoshi.moja3d.shaders.depth.DepthSkinShader;
	import net.morocoshi.moja3d.shaders.MaterialShader;
	import net.morocoshi.moja3d.shaders.ShaderList;
	
	use namespace moja3d;
	
	/**
	 * スキンシェーダー
	 * 
	 * @author tencho
	 */
	public class SkinShader extends MaterialShader 
	{
		private var numBones:int;
		private var boneList:Vector.<Bone>;
		private var skin:Skin;
		private var skinConst:AGALConstant;
		private var depthSkinShader:DepthSkinShader;
		private var reflectSkinShader:SkinShader;
		private var maskSkinShader:SkinShader;
		private var geometry:Geometry;
		
		public function SkinShader() 
		{
			super();
			
			requiredAttribute.push(VertexAttribute.BONEINDEX);
			requiredAttribute.push(VertexAttribute.BONEWEIGHT);
			//requiredAttribute.push(VertexAttribute.BONEINDEX2);
			//requiredAttribute.push(VertexAttribute.BONEWEIGHT2);
			
			boneList = new Vector.<Bone>;
			
			updateTexture();
			updateAlphaMode();
			updateConstants();
			updateShaderCode();
		}
		
		public function setGeometry(geometry:Geometry):void
		{
			this.geometry = geometry;
			updateShaderCode();
		}
		
		override public function afterCreateProgram(shaderList:ShaderList):void 
		{
			skinConst.x = shaderList.getVertexConstantIndex("@boneMatrix0:");
		}
		
		override public function getKey():String 
		{
			return "SkinShader:" + numBones;
		}
		
		override protected function updateAlphaMode():void
		{
			super.updateAlphaMode();
			alphaMode = AlphaMode.NONE;
		}
		
		override protected function updateTexture():void 
		{
			super.updateTexture();
		}
		
		/**
		 * ボーンリストを渡して定数を作成する。初回に一度だけ実行
		 * @param	bones
		 */
		public function initializeBones(bones:Vector.<Bone>, skin:Skin, phase:String):void
		{
			this.skin = skin;
			boneList.length = 0;
			numBones = bones.length;
			
			super.updateConstants();
			for (var i:int = 0; i < numBones; i++) 
			{
				var bone:Bone = bones[i];
				bone.setConstant(vertexCode.addConstantListFromMatrix("@boneMatrix" + i + ":", new Matrix3D(), true), phase);
				boneList.push(bone);
			}
			//[0]スキンMatrix定数の開始インデックス
			//[1]4
			skinConst = vertexCode.addConstantsFromArray("@skinData", [0, 4, 0, 0]);
			updateShaderCode();
		}
		
		/**
		 * ボーン姿勢から定数を更新する。描画毎に実行
		 */
		public function updateBoneConstants():void
		{
			var invertSkin:Matrix3D = skin._worldMatrix.clone();
			invertSkin.invert();
			
			var n:int = boneList.length;
			for (var i:int = 0; i < n; i++) 
			{
				boneList[i].invertSkinMatrix = invertSkin;
			}
		}
		
		override protected function updateShaderCode():void 
		{
			super.updateShaderCode();
			if (numBones == 0 || geometry == null) return;
			
			vertexConstants.number = true;
			vertexCode.addCode(
				"var $tempPosition",
				"var $tempNormal",
				"var $temp",
				"var $index",
				"$temp.xyzw = @0_0_0_1",
				"$tempPosition.xyzw = @0_0_0_1"
			);
			
			if (geometry.hasAttribute(VertexAttribute.NORMAL))
			{
				vertexCode.addCode("$tempNormal.xyzw = @0_0_0_1");
			}
			
			var boneIndex:String = "va" + geometry.getAttributeIndex(VertexAttribute.BONEINDEX);
			var boneWeight:String = "va" + geometry.getAttributeIndex(VertexAttribute.BONEWEIGHT);
			for (var i:int = 0; i < 4; i++) 
			{
				var xyzw:String = ["x", "y", "z", "w"][i];
				vertexCode.addCode(
					//使用インデックス＝ボーンインデックス*4+開始インデックス
					"$index.x = " + boneIndex + "." + xyzw + " * @skinData.y",
					"$index.x += @skinData.x",
					
					"$temp.xyzw = m44($pos.xyzw, vc[$index.x])",//元の座標を行列変換
					"$temp.xyz *= " + boneWeight + "." + xyzw + xyzw + xyzw,//ウェイトを乗算
					"$tempPosition.xyz += $temp.xyz"
				);
				
				if (geometry.hasAttribute(VertexAttribute.NORMAL))
				{
					vertexCode.addCode(
						"$temp.xyz = m33($normal.xyz, vc[$index.x])",//元の法線を行列変換
						"$temp.xyz *= " + boneWeight + "." + xyzw,//ウェイトを乗算
						"$tempNormal.xyz += $temp.xyz"
					);
				}
			}
			vertexCode.addCode(
				"$pos.xyz = $tempPosition.xyz",
				"$pos.w = @1",
				"$wpos = $pos"
			);
			if (geometry.hasAttribute(VertexAttribute.NORMAL))
			{
				vertexCode.addCode("$normal.xyz = nrm($tempNormal.xyz)");
			}
		}
		
		override public function clone():MaterialShader 
		{
			var shader:SkinShader = new SkinShader();
			shader.setGeometry(geometry);
			return shader;
		}
		
		override public function getExtraShader(phase:String):MaterialShader 
		{
			if (phase == RenderPhase.DEPTH)
			{
				if (depthSkinShader == null)
				{
					depthSkinShader = new DepthSkinShader();
					depthSkinShader.setGeometry(geometry);
					depthSkinShader.initializeBones(boneList, skin);
				}
				return depthSkinShader;
			}
			if (phase == RenderPhase.REFLECT)
			{
				if (reflectSkinShader == null)
				{
					reflectSkinShader = new SkinShader();
					reflectSkinShader.setGeometry(geometry);
					reflectSkinShader.initializeBones(boneList, skin, RenderPhase.REFLECT);
				}
				return reflectSkinShader;
			}
			if (phase == RenderPhase.MASK)
			{
				if (maskSkinShader == null)
				{
					maskSkinShader = new SkinShader();
					maskSkinShader.setGeometry(geometry);
					maskSkinShader.initializeBones(boneList, skin, RenderPhase.MASK);
				}
				return maskSkinShader;
			}
			return null;
		}
	}

}