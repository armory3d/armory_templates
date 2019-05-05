package arm;

import iron.math.Vec4;
import iron.math.Quat;
import iron.math.Mat4;
import iron.system.Input;
import iron.object.Object;
import iron.object.BoneAnimation;
import iron.system.Time;
import iron.system.Audio;
import armory.trait.physics.PhysicsWorld;
import armory.trait.internal.CameraController;

class ThirdPersonController extends CameraController {

#if (!arm_physics)
	public function new() { super(); }
#else

	static inline var rotationSpeed = 1.0;
	
	var stepTime = 0.0;
	var soundStep0:kha.Sound = null;
	var soundStep1:kha.Sound = null;

	var xVec = Vec4.xAxis();
	var zVec = Vec4.zAxis();
	var nextFrameRot = 0.0;
	var armature:Object;
	var anim:BoneAnimation;

	var speed = 1.0;
	var dir = new Vec4();
	var state = "idle";
	var jumping = false;

	public function new() {
		super();
		notifyOnInit(function() {
			PhysicsWorld.active.notifyOnPreUpdate(preUpdate);
			notifyOnUpdate(update);
			
			notifyOnRemove(function() {
				PhysicsWorld.active.removePreUpdate(preUpdate);
			});

			iron.data.Data.getSound("step0.wav", function(sound:kha.Sound) {
				soundStep0 = sound;
			});

			iron.data.Data.getSound("step1.wav", function(sound:kha.Sound) {
				soundStep1 = sound;
			});

			armature = object.getChild("Armature");
			anim = findAnimation(armature);
		});
	}

	function findAnimation(o:Object):BoneAnimation {
		if (o.animation != null) return cast o.animation;
		for (c in o.children) {
			var co = findAnimation(c);
			if (co != null) return co;
		}
		return null;
	}

	function preUpdate() {
		if (Input.occupied || !body.ready) return;
		
		var mouse = Input.getMouse();
		var kb = Input.getKeyboard();
		
		if (mouse.started() && !mouse.locked) mouse.lock();
		else if (kb.started("escape") && mouse.locked) mouse.unlock();
		
		if (nextFrameRot != 0.0) {
			var origin = object.getChild("CameraOrigin");
			origin.transform.rotate(xVec, nextFrameRot);
			origin.transform.buildMatrix();
		}
		nextFrameRot = 0;

		if (mouse.moved) {
			nextFrameRot = -mouse.movementY / 250 * rotationSpeed;
			transform.rotate(zVec, -mouse.movementX / 250 * rotationSpeed);
		}

		body.syncTransform();
	}

	function update() {
		if (!body.ready) return;

		var kb = iron.system.Input.getKeyboard();

		// Move
		dir.set(0, 0, 0);
		if (moveForward) dir.add(transform.look());
		if (moveBackward) dir.add(transform.look().mult(-1));
		if (moveLeft) dir.add(transform.right().mult(-1));
		if (moveRight) dir.add(transform.right());

		// Push down
		var btvec = body.getLinearVelocity();
		body.setLinearVelocity(0.0, 0.0, btvec.z - 1.0);

		if (moveForward || moveBackward || moveLeft || moveRight) {
			var action = moveForward  ? "run"  :
						 moveBackward ? "back" :
						 moveLeft     ? "left" : "right";
			setState(action);

			if (kb.down("shift")) speed = 1.6;
			else speed = 1.0;

			dir.mult(speed * 5);
			body.activate();
			body.setLinearVelocity(dir.x, dir.y, btvec.z - 1.0);

			stepTime += Time.delta;
			if (stepTime > 0.38 / speed) {
				stepTime = 0;
				Audio.play(Std.random(2) == 0 ? soundStep0 : soundStep1);
			}
		}
		// Play correct state
		else {
			setState("idle", 1.0);
		}

		if (jump && !jumping) {
			jumping = true;
			state = "jump";
			body.applyImpulse(new Vec4(0, 0, 20));
			anim.time = 0;
			anim.frameIndex = 0;
			// anim.play(state, function() { jumping = false; }, 0.0, 1.2);
			iron.system.Tween.timer(0.5, () -> jumping = false);
		}

		// Keep vertical
		body.setAngularFactor(0, 0, 0);
		camera.buildMatrix();
	}

	function setState(s:String, speed = 1.0, blend = 0.2) {
		if (s == state || jumping) return;
		state = s;
		anim.play(s, null, blend, speed);
	}
#end
}
