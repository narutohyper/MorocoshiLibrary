package net.morocoshi.moja3d.shaders.render 
{
	import net.morocoshi.moja3d.agal.AGALConstant;
	import net.morocoshi.moja3d.agal.AGALTexture;
	import net.morocoshi.moja3d.materials.Mipmap;
	import net.morocoshi.moja3d.materials.Smoothing;
	import net.morocoshi.moja3d.materials.Tiling;
	import net.morocoshi.moja3d.resources.TextureResource;
	import net.morocoshi.moja3d.resources.VertexAttribute;
	import net.morocoshi.moja3d.shaders.AlphaMode;
	import net.morocoshi.moja3d.shaders.MaterialShader;
	
	/**
	 * ライトマップテクスチャの明るい部分を発光させる
	 * 
	 * @author tencho
	 */
	public class LightMapShader extends MaterialShader 
	{
		private var _mipmap:String;
		private var _smoothing:String;
		private var _tiling:String;
		private var _resource:TextureResource;
		private var _intensity:Number;
		
		private var lightMapTexture:AGALTexture;
		private var intensityConst:AGALConstant;
		
		public function LightMapShader(resource:TextureResource, intensity:Number = 1, mipmap:String = "miplinear", smoothing:String = "linear", tiling:String = "wrap")
		{
			super();
			
			requiredAttribute.push(VertexAttribute.UV);
			
			_intensity = intensity;
			_resource = resource;
			_mipmap = mipmap;
			_smoothing = smoothing;
			_tiling = tiling;
			
			updateTexture();
			updateAlphaMode();
			updateConstants();
			updateShaderCode();
		}
		
		override public function getKey():String 
		{
			return "LightMapShader:" + _smoothing + "_" + _mipmap + "_" + _tiling + "_" + getSamplingKey(lightMapTexture);
		}
		
		override protected function updateAlphaMode():void
		{
			super.updateAlphaMode();
			alphaMode = AlphaMode.NONE;
		}
		
		override protected function updateTexture():void 
		{
			super.updateTexture();
			lightMapTexture = fragmentCode.addTexture("&lightMap", _resource, this);
		}
		
		override protected function updateConstants():void 
		{
			super.updateConstants();
			intensityConst = fragmentCode.addConstantsFromArray("@lightMapIntensity", [_intensity, 0, 0, 0]);
		}
		
		override protected function updateShaderCode():void 
		{
			super.updateShaderCode();
			
			var tag:String = getTextureTag(_smoothing, _mipmap, _tiling, lightMapTexture.getSamplingOption());
			fragmentCode.addCode([
				"var $image",
				"$image = tex(#uv, &lightMap " + tag + ")",
				"$image.x *= @lightMapIntensity.x",
				"$common.z = $image.x"
			]);
		}
		
		override public function reference():MaterialShader 
		{
			return new LightMapShader(_resource, _intensity, _mipmap, _smoothing, _tiling);
		}
		
		override public function clone():MaterialShader 
		{
			return new LightMapShader(cloneTexture(_resource), _intensity, _mipmap, _smoothing, _tiling);
		}
		
		public function get intensity():Number 
		{
			return _intensity;
		}
		
		public function set intensity(value:Number):void 
		{
			_intensity = value;
			intensityConst.x = value;
		}
		
	}

}