package celshade.renderpath;

import iron.RenderPath;

class RenderPathCreator {

	static var path:RenderPath;

	public static function get():RenderPath {
		path = new RenderPath();
		init();
		path.commands = commands;
		return path;
	}

	static function init() {

		#if kha_webgl
		initEmpty();
		#end

		#if (rp_background == "World")
		{
			path.loadShader("shader_datas/world_pass/world_pass");
		}
		#end

		#if rp_render_to_texture
		{
			path.createDepthBuffer("main", "DEPTH24");

			{
				var t = new RenderTargetRaw();
				t.name = "lbuf";
				t.width = 0;
				t.height = 0;
				t.format = getHdrFormat();
				t.displayp = getDisplayp();
				var ss = getSuperSampling();
				if (ss != 1) t.scale = ss;
				t.depth_buffer = "main";
				path.createRenderTarget(t);
			}

			#if rp_compositornodes
			{
				path.loadShader("shader_datas/compositor_pass/compositor_pass");
			}
			#else
			{
				path.loadShader("shader_datas/copy_pass/copy_pass");
			}
			#end

			#if (rp_supersampling == 4)
			{
				var t = new RenderTargetRaw();
				t.name = "buf";
				t.width = 0;
				t.height = 0;
				t.format = 'RGBA32';
				t.displayp = getDisplayp();
				var ss = getSuperSampling();
				if (ss != 1) t.scale = ss;
				t.depth_buffer = "main";
				path.createRenderTarget(t);

				path.loadShader("shader_datas/supersample_resolve/supersample_resolve");
			}
			#end
		}
		#end

		#if ((rp_antialiasing == "SMAA") || (rp_antialiasing == "TAA"))
		{
			var t = new RenderTargetRaw();
			t.name = "bufa";
			t.width = 0;
			t.height = 0;
			t.displayp = getDisplayp();
			t.format = "RGBA32";
			var ss = getSuperSampling();
			if (ss != 1) t.scale = ss;
			path.createRenderTarget(t);
		}
		{
			var t = new RenderTargetRaw();
			t.name = "bufb";
			t.width = 0;
			t.height = 0;
			t.displayp = getDisplayp();
			t.format = "RGBA32";
			var ss = getSuperSampling();
			if (ss != 1) t.scale = ss;
			path.createRenderTarget(t);
		}
		{
			path.loadShader("shader_datas/smaa_edge_detect/smaa_edge_detect");
			path.loadShader("shader_datas/smaa_blend_weight/smaa_blend_weight");
			path.loadShader("shader_datas/smaa_neighborhood_blend/smaa_neighborhood_blend");

			#if (rp_antialiasing == "TAA")
			{
				path.loadShader("shader_datas/taa_pass/taa_pass");
			}
			#end
		}
		#end

		#if rp_volumetriclight
		{
			path.loadShader("shader_datas/volumetric_light_quad/volumetric_light_quad");
			path.loadShader("shader_datas/volumetric_light/volumetric_light");
			path.loadShader("shader_datas/blur_bilat_pass/blur_bilat_pass_x");
			path.loadShader("shader_datas/blur_bilat_pass/blur_bilat_pass_y_blend");
			{
				var t = new RenderTargetRaw();
				t.name = "bufvola";
				t.width = 0;
				t.height = 0;
				t.displayp = getDisplayp();
				t.format = "R8";
				// var ss = getSuperSampling();
				// if (ss != 1) t.scale = ss;
				path.createRenderTarget(t);
			}
			{
				var t = new RenderTargetRaw();
				t.name = "bufvolb";
				t.width = 0;
				t.height = 0;
				t.displayp = getDisplayp();
				t.format = "R8";
				// var ss = getSuperSampling();
				// if (ss != 1) t.scale = ss;
				path.createRenderTarget(t);
			}
		}
		#end

		#if rp_bloom
		{
			var t = new RenderTargetRaw();
			t.name = "bloomtex";
			t.width = 0;
			t.height = 0;
			t.scale = 0.25;
			t.format = getHdrFormat();
			path.createRenderTarget(t);
		}

		{
			var t = new RenderTargetRaw();
			t.name = "bloomtex2";
			t.width = 0;
			t.height = 0;
			t.scale = 0.25;
			t.format = getHdrFormat();
			path.createRenderTarget(t);
		}

		{
			path.loadShader("shader_datas/bloom_pass/bloom_pass");
			path.loadShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");
			path.loadShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y");
			path.loadShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y_blend");
		}
		#end
	}

	static function commands() {

		#if rp_shadowmap
		{
			var faces = path.getLight(path.currentLightIndex).data.raw.shadowmap_cube ? 6 : 1;
			for (i in 0...faces) {
				if (faces > 1) path.currentFace = i;
				path.setTarget(getShadowMap());
				path.clearTarget(null, 1.0);
				path.drawMeshes("shadowmap");
			}
			path.currentFace = -1;
		}
		#end

		#if rp_render_to_texture
		{
			path.setTarget("lbuf");
		}
		#else
		{
			path.setTarget("");
		}
		#end

		#if (rp_background == "Clear")
		{
			path.clearTarget(-1, 1.0);
		}
		#else
		{
			path.clearTarget(null, 1.0);
		}
		#end

		#if rp_shadowmap
		{
			bindShadowMap();
		}
		#end

		path.drawMeshes("mesh");
		#if (rp_background == "World")
		{
			path.drawSkydome("shader_datas/world_pass/world_pass");
		}
		#end

		#if rp_render_to_texture
		{
			#if rp_volumetriclight
			{
				path.setTarget("bufvola");
				path.bindTarget("_main", "gbufferD");
				bindShadowMap();
				if (path.lightIsSun()) {
					path.drawShader("shader_datas/volumetric_light_quad/volumetric_light_quad");
				}
				else {
					path.drawLightVolume("shader_datas/volumetric_light/volumetric_light");
				}

				path.setTarget("bufvolb");
				path.bindTarget("bufvola", "tex");
				path.drawShader("shader_datas/blur_bilat_pass/blur_bilat_pass_x");

				path.setTarget("lbuf");
				path.bindTarget("bufvolb", "tex");
				path.drawShader("shader_datas/blur_bilat_pass/blur_bilat_pass_y_blend");
			}
			#end

			#if rp_bloom
			{
				path.setTarget("bloomtex");
				path.bindTarget("lbuf", "tex");
				path.drawShader("shader_datas/bloom_pass/bloom_pass");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("bloomtex");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("bloomtex");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("bloomtex");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("lbuf");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y_blend");
			}
			#end

			#if (rp_supersampling == 4)
			var framebuffer = "buf";
			#else
			var framebuffer = "";
			#end

			#if ((rp_antialiasing == "Off") || (rp_antialiasing == "FXAA"))
			{
				path.setTarget(framebuffer);
			}
			#else
			{
				path.setTarget("buf");
			}
			#end

			path.bindTarget("lbuf", "tex");

			#if rp_compositordepth
			{
				path.bindTarget("_main", "gbufferD");
			}
			#end

			#if rp_compositornodes
			{
				path.drawShader("shader_datas/compositor_pass/compositor_pass");
			}
			#else
			{
				path.drawShader("shader_datas/copy_pass/copy_pass");
			}
			#end

			#if ((rp_antialiasing == "SMAA") || (rp_antialiasing == "TAA"))
			{
				path.setTarget("bufa");
				path.clearTarget(0x00000000);
				path.bindTarget("lbuf", "colorTex");
				path.drawShader("shader_datas/smaa_edge_detect/smaa_edge_detect");

				path.setTarget("bufb");
				path.clearTarget(0x00000000);
				path.bindTarget("bufa", "edgesTex");
				path.drawShader("shader_datas/smaa_blend_weight/smaa_blend_weight");

				// #if (rp_antialiasing == "TAA")
				// path.setTarget("bufa");
				// #else
				path.setTarget(framebuffer);
				// #end
				path.bindTarget("lbuf", "colorTex");
				path.bindTarget("bufb", "blendTex");
				// #if (rp_antialiasing == "TAA")
				// {
					// path.bindTarget("gbuffer2", "sveloc");
				// }
				// #end
				path.drawShader("shader_datas/smaa_neighborhood_blend/smaa_neighborhood_blend");

				// #if (rp_antialiasing == "TAA")
				// {
				// 	path.setTarget(framebuffer);
				// 	path.bindTarget("bufa", "tex");
				// 	path.bindTarget("taa", "tex2");
				// 	path.bindTarget("gbuffer2", "sveloc");
				// 	path.drawShader("shader_datas/taa_pass/taa_pass");

				// 	path.setTarget("taa");
				// 	path.bindTarget("bufa", "tex");
				// 	path.drawShader("shader_datas/copy_pass/copy_pass");
				// }
				// #end
			}
			#end

			#if (rp_supersampling == 4)
			{
				var final = "";
				path.setTarget(final);
				path.bindTarget(framebuffer, "tex");
				path.drawShader("shader_datas/supersample_resolve/supersample_resolve");
			}
			#end
		}
		#end
	}

	static inline function getSuperSampling():Int {
		#if (rp_supersampling == 2)
		return 2;
		#elseif (rp_supersampling == 4)
		return 4;
		#else
		return 1;
		#end
	}

	static inline function getHdrFormat():String {
		#if rp_hdr
		return "RGBA64";
		#else
		return "RGBA32";
		#end
	}

	public static inline function getDisplayp():Null<Int> {
		#if rp_resolution_filter // Custom resolution set
		return Main.resolutionSize;
		#else
		return null;
		#end
	}

	static function bindShadowMap() {
		var target = shadowMapName();
		if (target == "shadowMapCube") {
			#if kha_webgl
			// Bind empty map to non-cubemap sampler to keep webgl happy
			path.bindTarget("arm_empty", "shadowMap");
			#end
			path.bindTarget("shadowMapCube", "shadowMapCube");
		}
		else {
			#if kha_webgl
			// Bind empty map to cubemap sampler
			path.bindTarget("arm_empty_cube", "shadowMapCube");
			#end
			path.bindTarget("shadowMap", "shadowMap");
		}
	}

	static function shadowMapName():String {
		return path.getLight(path.currentLightIndex).data.raw.shadowmap_cube ? "shadowMapCube" : "shadowMap";
	}

	static function getShadowMap():String {
		var target = shadowMapName();
		var rt = path.renderTargets.get(target);
		// Create shadowmap on the fly
		if (rt == null) {
			if (path.getLight(path.currentLightIndex).data.raw.shadowmap_cube) {
				// Cubemap size
				var size = Std.int(path.getLight(path.currentLightIndex).data.raw.shadowmap_size);
				var t = new RenderTargetRaw();
				t.name = target;
				t.width = size;
				t.height = size;
				t.format = "DEPTH16";
				t.is_cubemap = true;
				rt = path.createRenderTarget(t);
			}
			else { // Non-cube sm
				var sizew = path.getLight(path.currentLightIndex).data.raw.shadowmap_size;
				var sizeh = sizew;
				#if arm_csm // Cascades - atlas on x axis
				sizew = sizeh * iron.object.LightObject.cascadeCount;
				#end
				var t = new RenderTargetRaw();
				t.name = target;
				t.width = sizew;
				t.height = sizeh;
				t.format = "DEPTH16";
				rt = path.createRenderTarget(t);
			}
		}
		return target;
	}

	#if kha_webgl
	static function initEmpty() {
		// Bind empty when requested target is not found
		var tempty = new RenderTargetRaw();
		tempty.name = "arm_empty";
		tempty.width = 1;
		tempty.height = 1;
		tempty.format = "DEPTH16";
		path.createRenderTarget(tempty);
		var temptyCube = new RenderTargetRaw();
		temptyCube.name = "arm_empty_cube";
		temptyCube.width = 1;
		temptyCube.height = 1;
		temptyCube.format = "DEPTH16";
		temptyCube.is_cubemap = true;
		path.createRenderTarget(temptyCube);
	}
	#end
}
