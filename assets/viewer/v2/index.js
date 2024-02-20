// import * as BABYLON from 'babylonjs';

const canvas = document.getElementById("renderCanvas");
const engine = new BABYLON.Engine(canvas, true);
let scene = null;
let human = null;
const indexMapper = new MorphTargetMapIndex();
let visemes = [];
let visemesStartTime;
let mouthSmileMorphTarget;
let leftEyeBlinkMorphTarget;
let rightEyeBlinkMorphTarget;
let eyeLookUpLeftMorphTarget;
let eyeLookUpRightMorphTarget;
let eyeLookDownLeftMorphTarget;
let eyeLookDownRightMorphTarget;
let eyeLookInLeftMorphTarget;
let eyeLookInRightMorphTarget;
let eyeLookOutLeftMorphTarget;
let eyeLookOutRightMorphTarget;
let jawOpenMorphTarget;
let smileLowerLimit = 0.3;
var animationSwither = null;
var backgroudAnimation = null;
var smileIndex = new SmileIndex();
let light_intensity_delta = 0;
const FpsLimit = 60;

const createScene = async function () {
	const scene = new BABYLON.Scene(engine);
	scene.clearColor = new BABYLON.Color4(0, 0, 0, 0);

	// turn on debug layer when url has debug=1
	window.location.search?.substr(1).split('&').forEach((item) => {
		if (item === 'debug=1') {
			setTimeout(() => {
				scene.debugLayer.show();
			}, 10 * 1000);
		}
	});

	const alpha = -Math.PI / 2;
	const beta = Math.PI / 2;
	const cameraRadius = 1;
	const camera = new BABYLON.ArcRotateCamera("camera", alpha, beta, cameraRadius, new BABYLON.Vector3(0, 2.3, -1));
	camera.panningSensibility = 0;
	camera.inertia = 0;
	camera.lowerRadiusLimit = cameraRadius / 1.5;
	camera.upperRadiusLimit = cameraRadius * 1.5;
	camera.wheelDeltaPercentage = 0.01;
	camera.lowerAlphaLimit = alpha - Math.PI / 2;
	camera.upperAlphaLimit = alpha + Math.Pi / 2;
	camera.lowerBetaLimit = beta - Math.PI / 2;
	camera.upperBetaLimit = beta + Math.PI / 2;
	// camera.inputs.remove(camera.inputs.attached.pointers);
	camera.attachControl(canvas, true);
	const light = new BABYLON.HemisphericLight("light", new BABYLON.Vector3(10, 2, 0));
	light.intensity = 0.5
	console.log('light intensity', light.intensity)
	backgroudAnimation = new BackgroudAnimation(scene, camera, light, FpsLimit, light.intensity, 1.5, cameraRadius * 0.9, cameraRadius);

	// const meshes = await BABYLON.SceneLoader.ImportMeshAsync("", "./", "zhugeliang.low.mouthSmile.ARKit.glb");
	const meshes = await BABYLON.SceneLoader.ImportMeshAsync("", "./", "zs.glb");
	meshes.meshes.forEach(mesh => {
		mesh.scaling = new BABYLON.Vector3(2, 2, 2);
	});
	human = meshes.meshes[1];
	console.log(human);
	indexMapper.initMapWithMorphTargetManager(human.morphTargetManager);
	console.log('indexMapper got', indexMapper.getMappedSize(), 'items');
	// const eyeBlinkLeftMorphtarget = human.morphTargetManager.getTarget(indexMapper.getIndexByName('eyeBlinkLeft'));
	// eyeBlinkLeftMorphtarget.influence = 1;
	mouthSmileMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('mouthSmile', human.morphTargetManager))
	mouthSmileMorphTarget.influence = smileLowerLimit;
	leftEyeBlinkMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('eyeBlinkLeft', human.morphTargetManager))
	leftEyeBlinkMorphTarget.influence = 0;
	rightEyeBlinkMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('eyeBlinkRight', human.morphTargetManager))
	rightEyeBlinkMorphTarget.influence = 0;
	eyeLookUpLeftMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('eyeLookUpLeft', human.morphTargetManager))
	eyeLookUpLeftMorphTarget.influence = 0;
	eyeLookUpRightMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('eyeLookUpRight', human.morphTargetManager))
	eyeLookUpRightMorphTarget.influence = 0;
	eyeLookDownLeftMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('eyeLookDownLeft', human.morphTargetManager))
	eyeLookDownLeftMorphTarget.influence = 0;
	eyeLookDownRightMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('eyeLookDownRight', human.morphTargetManager))
	eyeLookDownRightMorphTarget.influence = 0;
	eyeLookInLeftMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('eyeLookInLeft', human.morphTargetManager))
	eyeLookInLeftMorphTarget.influence = 0;
	eyeLookInRightMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('eyeLookInRight', human.morphTargetManager))
	eyeLookInRightMorphTarget.influence = 0;
	eyeLookOutLeftMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('eyeLookOutLeft', human.morphTargetManager))
	eyeLookOutLeftMorphTarget.influence = 0;
	eyeLookOutRightMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('eyeLookOutRight', human.morphTargetManager))
	eyeLookOutRightMorphTarget.influence = 0;
	jawOpenMorphTarget = human.morphTargetManager.getTarget(indexMapper.getTargetIndexByName('jawOpen', human.morphTargetManager))
	jawOpenMorphTarget.influence = 0;


	// under: Armature
	// default_animation_file = "RPM_Anime_Combined.glb";
	// default_animation_file = "idle1.glb"
	// await BABYLON.SceneLoader.ImportAnimationsAsync('./', default_animation_file, scene, false,
	// 	BABYLON.SceneLoaderAnimationGroupLoadingMode.Stop, null);
	// console.log(scene.animationGroups);


	//add environment and floor
	var skybox = BABYLON.MeshBuilder.CreateBox("skyBox", { size: 1000.0 }, scene);
	const skyMaterial = new BABYLON.SkyMaterial("skyMaterial", scene);
	skyMaterial.backFaceCulling = false;
	skyMaterial.inclination = 0.10;
	skyMaterial.azimuth = 0.9;

	skybox.material = skyMaterial;
	// skybox.rotation.y = Math.PI / 3;

	// create a dark floor
	var ground = BABYLON.MeshBuilder.CreateGround("ground", { width: 1000, height: 1000 }, scene);
	var groundMaterial = new BABYLON.StandardMaterial("ground", scene);
	groundMaterial.diffuseTexture = new BABYLON.Texture("textures/ground.jpg", scene);//, false, true, BABYLON.Texture.NEAREST_SAMPLINGMODE);
	ground.material = groundMaterial;
	ground.material.diffuseColor = new BABYLON.Color3(3, 3, 3);
	// set scale of the ground
	let scale = 0.2
	ground.scaling = new BABYLON.Vector3(scale, scale, scale);

	scene.stopAllAnimations();


	scene.registerBeforeRender(() => {
		camera.alpha += 0.0002 * Math.sin(window.frameCount / 60);
		camera.beta += 0.0001 * Math.cos(window.frameCount / 30);
		// light 亮度和位置周期调整
		light.intensity = 1 + light_intensity_delta + 0.1 * Math.sin(window.frameCount / 90);
		light.position = new BABYLON.Vector3(10 * Math.cos(window.frameCount / 100), 2, 10 * Math.sin(window.frameCount / 100));

		// setting morphTarget.influence every frame
		// let influenceFromInput = smileIndex.getCurrentSmileIndex();
		// let influenceToSet = influenceFromInput / 100 * (1 - smileLowerLimit) + smileLowerLimit;
		// mouthSmileMorphTarget.influence += (influenceToSet - mouthSmileMorphTarget.influence) * 0.03;
		// setting morphTarget.influence every frame
		// visemes 60 fps
		let now = new Date().getTime();
		if (!visemes || visemes.length < 1 || !visemesStartTime) {
			return;
		}
		var frameIndex = Math.floor((now - visemesStartTime) / (1000 / 60));
		if (frameIndex >= visemes.length) {
			visemes = [];
			visemesStartTime = 0;
			light_intensity_delta = 0;
			console.log('visemes end')
			backgroudAnimation.setVisemesEnd();
			return;
		}
		let frameCount = visemes.length;
		let morphCount = frameCount > 0 ? visemes[0].length : 0;
		if (morphCount < 1) return;
		// shoud be 55
		for (let i = 0; i < morphCount; i++) {
			let index = indexMapper.getIndexByArkitIndex(i);
			if (index >= 0) {
				human.morphTargetManager.getTarget(index).influence = visemes[frameIndex][i] / 1000;
			}
		}

	});

	return scene;
};

// visemesValuesString: [[171,164,38,0,0,95,0,171,164,74,0,0,95,0,81,28,0,254,161,182,110,11,4,20,29,30,16,56,51,123,99,64,57,18,100,23,24,290,287,20,20,14,14,91,0,0,21,54,58,38,39,0,13,-1,2], ...]
async function setVisemes(visemesValuesString) {
	setTimeout(() => {
		try {
			visemes = JSON.parse(visemesValuesString);
			visemesStartTime = new Date().getTime();
			light_intensity_delta = 0.8;
			console.log('setVisemes: ', visemes, ', visemesStartTime: ', visemesStartTime, ', light_intensity_delta: ', light_intensity_delta)
			sendMessageToApp("got new visemes.length: " + visemes.length + ', talkAnimName: ' + talkAnimName);
			// motions: Dance_GangnamStyle, Dance_Silly, Dance_Uprock, Greeting, Jump, Walk, Run, Walk_Backward
			// talk: idle0, idle1, idle2
			// let talkAnimName = '';
			// const talks = ['Idle']; // talk0, talk3
			// const motions = ['Dance_GangnamStyle', 'Dance_Silly', 'Dance_Uprock', 'Greeting'];
			// if (smileIndex.getCurrentSmileIndex() > 50) {
			// 	talkAnimName = motions[Math.floor(Math.random() * motions.length)];
			// } else {
			// 	talkAnimName = talks[Math.floor(Math.random() * talks.length)];
			// }
			// animationSwither && animationSwither.playAnimationGroup(talkAnimName, false);
		} catch (error) {
			sendMessageToApp("error parsing visemes: " + error)
		}
	}, 10);
}

async function appendVisemes(visemesValuesString) {
	try {
		let newVisemes = JSON.parse(visemesValuesString);
		if (visemes.length < 1) {
			visemesStartTime = new Date().getTime();
			light_intensity_delta = 0.8;
		}
		visemes = visemes.concat(newVisemes);
		console.log('appendVisemes: ', newVisemes, ', visemes.length: ', visemes.length)
		sendMessageToApp("append new visemes.length: " + newVisemes.length + ', visemes.length: ' + visemes.length);
	} catch (error) {
		sendMessageToApp("error parsing visemes: " + error)
	}
}

async function clearVisemes() {
	visemes = [];
	visemesStartTime = 0;
	light_intensity_delta = 0;
	console.log('clearVisemes')
	sendMessageToApp("clear visemes");
}

async function playBlinkAnimation() {
	if (!human || !mouthSmileMorphTarget) {
		console.log('playMorphTargetAnimation: human or mouthSmileMorphTarget is null')
		return;
	}

	let randomTime = Math.floor(Math.random() * 4000) + 1000;
	await sleep(randomTime);
	console.log('playBlinkAnimation after randomTime: ', randomTime)
	let steps = 6;
	for (let i = 0; i < steps; i++) {
		await sleep(33.3);
		leftEyeBlinkMorphTarget.influence = i / steps;
		rightEyeBlinkMorphTarget.influence = i / steps;
	}
	for (let i = 0; i < steps; i++) {
		await sleep(33.3);
		leftEyeBlinkMorphTarget.influence = (steps - i) / steps;
		rightEyeBlinkMorphTarget.influence = (steps - i) / steps;
	}
	setTimeout(playBlinkAnimation, 3 * 1000);
}
setTimeout(playBlinkAnimation, 6 * 1000);


let nextSmileInfluence = 0.5;
let nextJawOpenInfluence = 0.3;
async function playSmileAnimation() {
	if (!human || !mouthSmileMorphTarget || !jawOpenMorphTarget) {
		console.log('playMorphTargetAnimation: human or mouthSmileMorphTarget or jawOpenMorphTarget is null')
		return;
	}
	console.log('playSmileAnimation, nextSmileInfluence: ', nextSmileInfluence, ', nextJawOpenInfluence: ', nextJawOpenInfluence)
	let currentSmileInfluence = mouthSmileMorphTarget.influence;
	let currentJawOpenInfluence = jawOpenMorphTarget.influence;
	nextJawOpenInfluence = Math.random() * 0.1 + 0.005;
	nextSmileInfluence = Math.random() * 0.2 + 0.2;
	// reset other mouth morph targets
	let steps = 20 * Math.random() + 20;
	for (let i = 0; i < steps; i++) {
		await sleep(33.3);
		mouthSmileMorphTarget.influence = currentSmileInfluence + (nextSmileInfluence - currentSmileInfluence) * i / steps;
		jawOpenMorphTarget.influence = currentJawOpenInfluence + (nextJawOpenInfluence - currentJawOpenInfluence) * i / steps;
	}
	setTimeout(playSmileAnimation, 500);
}
setTimeout(playSmileAnimation, 5 * 1000);


let nextLookX = 0
let nextLookY = 0
let currentLookX = 0
let currentLookY = 0
async function playEyeLookAroundAnimation() {
	if (!human || !eyeLookUpLeftMorphTarget || !eyeLookUpRightMorphTarget || !eyeLookDownLeftMorphTarget || !eyeLookDownRightMorphTarget || !eyeLookInLeftMorphTarget || !eyeLookInRightMorphTarget || !eyeLookOutLeftMorphTarget || !eyeLookOutRightMorphTarget) {
		console.log('playEyeLookAroundAnimation: human or eyeLookAroundMorphTarget is null')
		return;
	}
	let randomTime = Math.floor(Math.random() * 1000) + 500;
	await sleep(randomTime);
	nextLookX = Math.random() * 0.2 - 0.1;
	nextLookY = Math.random() * 0.2 - 0.1;
	console.log('playEyeLookAroundAnimation, nextLookX: ', nextLookX, ', nextLookY: ', nextLookY)
	let scale = (0.5 * Math.random() + 0.5) * 3;
	let steps = 5 * Math.random() + 5;
	steps = Math.floor(steps);
	for (let i = 0; i < steps; i++) {
		await sleep(33.3);
		x = currentLookX + (nextLookX - currentLookX) * i / steps;
		y = currentLookY + (nextLookY - currentLookY) * i / steps;
		if (x >= 0) {
			eyeLookInLeftMorphTarget.influence = x * scale;
			eyeLookOutRightMorphTarget.influence = x * scale;
			eyeLookOutLeftMorphTarget.influence = 0;
			eyeLookInRightMorphTarget.influence = 0;
		} else {
			eyeLookInLeftMorphTarget.influence = 0;
			eyeLookOutRightMorphTarget.influence = 0;
			eyeLookOutLeftMorphTarget.influence = -x * scale;
			eyeLookInRightMorphTarget.influence = -x * scale;
		}

		if (y >= 0) {
			eyeLookUpLeftMorphTarget.influence = y * scale;
			eyeLookUpRightMorphTarget.influence = y * scale;
			eyeLookDownLeftMorphTarget.influence = 0;
			eyeLookDownRightMorphTarget.influence = 0;
		} else {
			eyeLookUpLeftMorphTarget.influence = 0;
			eyeLookUpRightMorphTarget.influence = 0;
			eyeLookDownLeftMorphTarget.influence = -y * scale;
			eyeLookDownRightMorphTarget.influence = -y * scale;
		}

	}
	currentLookX = nextLookX;
	currentLookY = nextLookY;
	setTimeout(playEyeLookAroundAnimation, 1 * 1000);
}
setTimeout(playEyeLookAroundAnimation, 3 * 1000);




function setMouthSmileMorphTargetInfluence(influence) {
	// input influence: 0 - 100
	if (influence < 0 || influence > 100) return;
	smileIndex.insertSmileIndex(influence);
	console.log('setMouthSmileMorphTargetInfluence', influence)
}

// for console test
async function testVisemes() {
	fetch('visemes.json')
		.then(response => response.text())
		.then(data => {
			console.log('got visemes.json')
			setVisemes(data)
		}
		);
}


setInterval(() => {
	let divFps = document.getElementById("fps");
	divFps.innerHTML = 'FPS:' + getFPS().toFixed() + ", JSHeap: " + (performance.memory.usedJSHeapSize / 1024 / 1024).toFixed() + " M";
}, 1000);


async function main() {
	scene = await createScene();
	limitLoop(scene.render.bind(scene), FpsLimit);

	// animationSwither = new AnimationSwither(scene, backgroudAnimation);
	// scene.registerBeforeRender(animationSwither.onBeforeAnimation.bind(animationSwither));
	// animationSwither.playAnimationGroup(animationSwither.defaultAnimationGroupName, true);

	// Watch for browser/canvas resize events
	window.addEventListener("resize", function () {
		engine.resize();
	});
};
main();

sendMessageToApp("hello from index.js");