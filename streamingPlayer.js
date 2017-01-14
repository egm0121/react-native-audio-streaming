import {
    NativeModules,
    DeviceEventEmitter,
    Platform
} from 'react-native';
import EventEmitter from 'es2015-event-emitter';
const { ReactNativeAudioStreaming } = NativeModules;
let NATIVE_INSTANCE_COUNTER = 0;
let instanceMap = {};
//@TODO : extend an EventEmitter or mixin EE instance
function subscribeGlobalAudioEvents(){
  DeviceEventEmitter.addListener(
     'AudioBridgeEvent', (evt) => {
       if('playerId' in evt && instanceMap[evt.playerId] !== undefined){
         instanceMap[evt.playerId].dispatchAudioEvent(evt);
       }
     }
 );
}
class ReactNativeStreamingPlayer extends EventEmitter {
  constructor(soundUrl){
      super();
      this._nativeInstanceId = NATIVE_INSTANCE_COUNTER++;
      this._currentSoundUrl = soundUrl;
      ReactNativeAudioStreaming.createPlayer(this._nativeInstanceId);
      instanceMap[this._nativeInstanceId] = this;
  }
  _bindPlayerEvents(){

  }
  dispatchAudioEvent(evt){
    this.trigger('AudioBridgeEvent',evt);
  }
  play(){
    ReactNativeAudioStreaming.playWithKey(this._nativeInstanceId,this._currentSoundUrl);
  }
  pause(){
    ReactNativeAudioStreaming.pauseWithKey(this._nativeInstanceId);
  }
  resume(){
    ReactNativeAudioStreaming.resumeWithKey(this._nativeInstanceId);
  }
  stop(){
    ReactNativeAudioStreaming.stopWithKey(this._nativeInstanceId);
  }
  setVolume(volInt){
    ReactNativeAudioStreaming.setVolumeWithKey(this._nativeInstanceId,volInt);
  }
  setPan(panInt){
    panInt = parseInt(panInt);
    if(panInt < -1 || panInt > 1){
      throw new Error("Out of range pan value provided");
    }
    ReactNativeAudioStreaming.setPanWithKey(this._nativeInstanceId,panInt);
  }
  seekToTime(secondsDouble){
    ReactNativeAudioStreaming.seekToTimeWithKey(this._nativeInstanceId,secondsDouble);
  }
  goForwardWithKey(secondsDouble){
    ReactNativeAudioStreaming.goForwardWithKey(this._nativeInstanceId,secondsDouble);
  }
  goBackWithKey(secondsDouble){
    ReactNativeAudioStreaming.goBackWithKey(this._nativeInstanceId,secondsDouble);
  }
  setSoundUrl(urlString){
    this._currentSoundUrl = urlString;
  }
  getSoundUrl(){
    return this._currentSoundUrl;
  }
  getPan(cb){ //@TODO: implement objective-c bridged methods for getters
    return ReactNativeAudioStreaming.getPanWithKey(this._nativeInstanceId,(err,data) => {
      cb(err,data.pan);
    });
  }
  getVolume(cb){
    return ReactNativeAudioStreaming.getVolumeWithKey(this._nativeInstanceId,(err,data) => {
      cb(err,data.volume);
    });
  }
  isPaused (cb){
    ReactNativeAudioStreaming.getStatusWithKey(this._nativeInstanceId,(err,data) => {
      cb(err,data.status == "PAUSED");
    });
  }
  isPlaying (cb){
    ReactNativeAudioStreaming.getStatusWithKey(this._nativeInstanceId,(err,data) => {
      console.log('callback for getStatus called')
      cb(err,data.status == "PLAYING");
    });
  }
  getPosition(cb){
    ReactNativeAudioStreaming.getStatusWithKey(this._nativeInstanceId,(err,data) => {
      console.log('callback for getStatus called')
      cb(err,data.progress,data.duration);
    });
  }
  getStatus(cb){
    ReactNativeAudioStreaming.getStatusWithKey(this._nativeInstanceId,cb);
  }
  destroy(){
    ReactNativeAudioStreaming.destroyWithKey(this._nativeInstanceId);
    instanceMap[this._nativeInstanceId] = undefined;
  }
}
subscribeGlobalAudioEvents();
export default ReactNativeStreamingPlayer;
