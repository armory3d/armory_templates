package arm;

import iron.math.Vec4;
import iron.math.Vec2;
import iron.math.RayCaster;
import iron.Scene;
import iron.object.Object;
import iron.object.BoneAnimation;
import iron.system.Time;
import iron.system.Audio;
import iron.system.Input;
import armory.trait.physics.RigidBody;

class PlayerController extends iron.Trait {

#if (!arm_physics)
	public function new() { super(); }
#else
	
	var soundStep0:kha.Sound = null;
	var soundStep1:kha.Sound = null;

	var mouse:Mouse = null;
	var keyboard:Keyboard = null;
	var gamepad:Gamepad = null;

	var body:RigidBody;
	var anim:BoneAnimation;
	var armature:Object;

	var stepTime = 0.0;
	var turnTime = 0.0;
	var dir = new Vec4();
	var lastLook:Vec4;
	var state = "idle";

	public function new() {
		super();
		notifyOnInit(init);
		notifyOnUpdate(update);
	}

	function init() {
		// Get input devices
		mouse = Input.getMouse();
		keyboard = Input.getKeyboard();
		gamepad = Input.getGamepad(0);

		// Store references
		body = object.getTrait(RigidBody);
		armature = object.getChild("Armature");
		anim = cast armature.children[0].animation;
		lastLook = armature.transform.look().normalize();

		// Load sounds
		iron.data.Data.getSound("step0.wav", function(sound:kha.Sound) { soundStep0 = sound; });
		iron.data.Data.getSound("step1.wav", function(sound:kha.Sound) { soundStep1 = sound; });
	}

	function update() {
		// Movement
		dir.set(0, 0, 0);
		if (keyboard.down("w")) dir.y = 1.0;
		if (keyboard.down("s")) dir.y = -1.0;
		if (keyboard.down("a")) dir.x = -1.0;
		if (keyboard.down("d")) dir.x = 1.0;
		if (gamepad != null && Math.abs(gamepad.leftStick.x) > 0.1) dir.x = gamepad.leftStick.x;
		if (gamepad != null && Math.abs(gamepad.leftStick.y) > 0.1) dir.y = gamepad.leftStick.y;
		dir.normalize();

		// Mouse control
		var mouse_pos = new Vec2(mouse.x,mouse.y);
		var hit_pos = project_mouse_pos(mouse_pos);

		if (hit_pos != null)
		{
			var center = new Vec4(hit_pos.x,hit_pos.y,0);
			var eye = armature.transform.world.getLoc();
			eye.set(eye.x,eye.y,0);

			var target = center.sub(eye);

			armature.transform.rot.fromTo(Vec4.yAxis(), target.normalize());
		}

		// Gamepad control
		if (gamepad != null) {
			if (Math.abs(gamepad.rightStick.x) > 0.7 || Math.abs(gamepad.rightStick.y) > 0.7) {
				armature.transform.rot.fromTo(Vec4.yAxis(), new Vec4(gamepad.rightStick.x, gamepad.rightStick.y, 0.0));
			}
		}

		armature.transform.buildMatrix();
		updateAnim();
		updateBody();
	}

	function project_mouse_pos(input:Vec2){
		var camera = Scene.active.camera;

		var start = new Vec4();
		var end = new Vec4();
		
		var hit_pos = RayCaster.planeIntersect(Vec4.zAxis(),new Vec4(0,0,1),input.x,input.y,camera);
		return hit_pos;
	}

	function getAngle(va:Vec4, vb:Vec4) {
		var vn = Vec4.zAxis();
		var dot = va.dot(vb);
		var det = va.x * vb.y * vn.z +
				  vb.x * vn.y * va.z +
				  vn.x * va.y * vb.z -
				  va.z * vb.y * vn.x -
				  vb.z * vn.y * va.x -
				  vn.z * va.y * vb.x;
		return Math.atan2(det, dot);
	}

	function updateAnim() {
		var look = armature.transform.look().normalize();

		// Move
		if (dir.length() > 0) {
			var action = "";
			// Angle from look direction to move direction
			// 0 to PI * 2
			var angle = getAngle(dir, look) + Math.PI;
			var step = Math.PI / 4;
			if (angle < step) action = "back";
			else if (angle < step * 3) action = "left";
			else if (angle < step * 5) action = "run";
			else if (angle < step * 7) action = "right";
			else action = "back";

			setState(action, 1.0);

			// Step sounds
			stepTime += Time.delta;
			if (stepTime > 0.3) {
				stepTime = 0;
				Audio.play(Std.random(2) == 0 ? soundStep0 : soundStep1);
			}
		}
		// Shoot
		else if (mouse.down("left") || (gamepad != null && gamepad.down("r2") > 0.0)) {
			setState("fire", 2.0);
		}
		// Idle
		else {
			var angle = getAngle(look, lastLook);
			if (Math.abs(angle) > 0.01) {
				setState("turn", angle > 0 ? 1 : -1, 0);
				turnTime = 0;
			}
			else if (turnTime > 0.25){
				setState("idle", 2.0);
			}
			else turnTime += Time.delta;
		}

		lastLook.setFrom(look);
	}

	function updateBody() {
		if (!body.ready) return;
		
		body.syncTransform();
		body.activate();
		var linvel = body.getLinearVelocity();
		body.setLinearVelocity(dir.x * 6, dir.y * 6, linvel.z - 1.0); // Push down
		body.setAngularFactor(0, 0, 0); // Keep vertical
	}

	function setState(s:String, speed:Float, blend = 0.2) {
		if (s == state) return;
		state = s;
		anim.play(s, null, blend, speed);
	}
#end
}
