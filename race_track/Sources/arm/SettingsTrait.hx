package arm;

import iron.Scene;
import armory.system.Event;
import armory.data.Config;
import armory.trait.internal.CanvasScript;
import armory.renderpath.RenderPathCreator;

class SettingsTrait extends iron.Trait {

	var canvas:CanvasScript;
	var envStrength = 0.0;

	public function new() {
		super();

		notifyOnInit(function() {
			canvas = Scene.active.getTrait(CanvasScript);

			// Init UI to values loaded from config.arm file
			canvas.notifyOnReady(function() {
				canvas.getElement("MenuContainer").visible = false;
				canvas.getHandle("SSAO").selected = Config.raw.rp_ssgi;
				canvas.getHandle("SSR").selected = Config.raw.rp_ssr;
				canvas.getHandle("Bloom").selected = Config.raw.rp_bloom;
				canvas.getHandle("Voxels").selected = Config.raw.rp_gi;
				canvas.getHandle("Shadows").position = getShadowQuality(Config.raw.rp_shadowmap_cascade);
			});
			
			// Button events
			Event.add("toggle_menu", toggleMenu);
			Event.add("apply_settings", applySettings);
		});
	}

	function toggleMenu() {
		var e = canvas.getElement("MenuContainer");
		e.visible = !e.visible;
	}

	function applySettings() {

		// Apply render path settings
		Config.raw.rp_ssgi = canvas.getHandle("SSAO").selected;
		Config.raw.rp_ssr = canvas.getHandle("SSR").selected;
		Config.raw.rp_bloom = canvas.getHandle("Bloom").selected;
		Config.raw.rp_gi = canvas.getHandle("Voxels").selected;
		Config.raw.rp_shadowmap_cascade = getShadowMapSize(canvas.getHandle("Shadows").position);
		RenderPathCreator.applyConfig();

		// Lower envmap strength when voxel ao is disabled
		var p = iron.Scene.active.world.probe.raw;
		if (envStrength == 0) envStrength = p.strength;
		p.strength = Config.raw.rp_gi ? envStrength : envStrength / 3;

		// Save config.arm file
		Config.save();
	}

	inline function getShadowQuality(i:Int):Int {
		// 0 - High, 1 - Medium, 2 - Low
		return i == 4096 ? 0 : i == 2048 ? 1 : 2;
	}

	inline function getShadowMapSize(i:Int):Int {
		return i == 0 ? 4096 : i == 1 ? 2048 : 1024;
	}
}
