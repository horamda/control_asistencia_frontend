const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const source = require('node:fs').readFileSync(require('node:path').join(__dirname, '../web/rear_camera.js'), 'utf8');
function setup(open, cameras) {
 const devices = {getUserMedia: open, enumerateDevices: async () => cameras};
 const context = {navigator: {mediaDevices: devices}};
 vm.runInNewContext(source, context);
 return {devices, next: context.fichaYaNextCamera};
}
const cameras = [
 {kind:'videoinput', deviceId:'front', label:'Front Camera'},
 {kind:'videoinput', deviceId:'back', label:'Back Camera'},
 {kind:'videoinput', deviceId:'extra', label:''}
];
const stream = id => ({getVideoTracks: () => [{getSettings: () => ({deviceId:id})}]});
test('starts with rear preference and accepts a working front camera', async () => {
 const {devices} = setup(async c => {assert.equal(c.video.facingMode.ideal,'environment'); return stream('front');}, cameras);
 await devices.getUserMedia({video:true});
});
test('cycles all cameras from actual active device and wraps around', async () => {
 const ids=[];
 const {devices,next}=setup(async c=> {const id=c.video.deviceId?.exact || 'front'; ids.push(id); return stream(id);},cameras);
 await devices.getUserMedia({video:true});
 for(let i=0;i<3;i++){await next();await devices.getUserMedia({video:true});}
 assert.deepEqual(ids,['front','back','extra','front']);
});
test('failed camera can be skipped on next tap without silent fallback', async () => {
 const ids=[];
 const {devices,next}=setup(async c=> {const id=c.video.deviceId?.exact || 'front';ids.push(id);if(id==='back') throw new Error('busy');return stream(id);},cameras);
 await devices.getUserMedia({video:true});await next();
 await assert.rejects(devices.getUserMedia({video:true}));
 await next();await devices.getUserMedia({video:true});
 assert.deepEqual(ids,['front','back','extra']);
});
test('audio requests and empty camera list are handled', async () => {
 const c={audio:true};const {devices,next}=setup(async c=>c,[]);
 assert.equal(await devices.getUserMedia(c),c);assert.equal(await next(),'');
});
