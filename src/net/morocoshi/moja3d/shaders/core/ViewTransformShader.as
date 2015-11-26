package net.morocoshi.moja3d.shaders.core 
{
	import net.morocoshi.moja3d.shaders.AlphaMode;
	import net.morocoshi.moja3d.shaders.MaterialShader;
	
	/**
	 * ビュー行列変換
	 * 
	 * @author tencho
	 */
	public class ViewTransformShader extends MaterialShader 
	{
		
		public function ViewTransformShader() 
		{
			super();
			
			updateTexture();
			updateAlphaMode();
			updateConstants();
			updateShaderCode();
		}
		
		override public function getKey():String 
		{
			return "ViewTransformShader:";
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
		
		override protected function updateConstants():void 
		{
			super.updateConstants();
		}
		
		override protected function updateShaderCode():void 
		{
			super.updateShaderCode();
			
			vertexConstants.viewMatrix = true;
			vertexCode.addCode([
				//position
				"#wpos = $wpos",
				"$pos.xyz = m34($pos, @viewMatrix)"//ビュー行列で変換
			]);
		}
		
		override public function clone():MaterialShader 
		{
			return new ViewTransformShader();
		}
		
	}

}