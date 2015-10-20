package net.morocoshi.moja3d.resources 
{
	import flash.display3D.Context3D;
	import flash.display3D.Context3DTextureFormat;
	
	/**
	 * ...
	 * 
	 * @author tencho
	 */
	public class RenderTextureResource extends TextureResource 
	{
		private var _lowLV:int;
		public var limitW:int;
		public var limitH:int;
		
		public function RenderTextureResource(limitW:int = 1024, limitH:int = 1024, lowLV:int = 0, name:String = "") 
		{
			super();
			_lowLV = lowLV;
			this.name = name;
			this.limitW = limitW;
			this.limitH = limitH;
			isReady = true;
		}
		
		public function fillColor(context3D:Context3D, rgb:uint, alpha:Number = 1):void
		{
			context3D.setRenderToTexture(texture, true, 0);
			context3D.clear((rgb >> 16 & 0xff) / 0xff, (rgb >> 8 & 0xff) / 0xff, (rgb & 0xff) / 0xff, alpha);
			isUploaded = true;
		}
		
		//レンダリング用テクスチャの場合
		override public function createTexture(context3D:Context3D, width:int, height:int):void 
		{
			if (width > limitW) width = limitW;
			if (height > limitH) height = limitH;
			
			//サイズ修正(2の累乗に直す)
			var notPow2:Boolean = !TextureUtil.checkPow2(width, height);
			if (notPow2)
			{
				width = TextureUtil.toPow2(width);
				height = TextureUtil.toPow2(height);
				notPow2 = false;
			}
			
			width = width >> _lowLV;
			height = height >> _lowLV;
			
			//前回と同じならスキップ
			if (prevSize.x == width && prevSize.y == height)
			{
				return;
			}
			
			prevSize.x = width;
			prevSize.y = height;
			
			if (texture)
			{
				texture.dispose();
			}
			
			texture = context3D.createTexture(width, height, Context3DTextureFormat.BGRA, true);
			//RectangleTextureを使った場合
			//texture = context3D.createRectangleTexture(width, height, format, renderToTexture);
		}
		
		override public function upload(context3D:Context3D, async:Boolean = false, complete:Function = null):void 
		{
		}
		
		override public function clone():Resource 
		{
			return new RenderTextureResource(limitW, limitH, _lowLV);
		}
		
	}

}