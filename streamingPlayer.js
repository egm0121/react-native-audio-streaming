import {
    NativeModules,
    DeviceEventEmitter,
    Platform
} from 'react-native';

const { ReactNativeAudioStreaming } = NativeModules;
let NATIVE_INSTANCE_COUNTER = 0;
//@TODO : extend an EventEmitter or mixin EE instance

class ReactNativeStreamingPlayer {
  constructor(soundUrl){
      this._nativeInstanceId = NATIVE_INSTANCE_COUNTER++;
      this._currentSoundUrl = soundUrl;
      ReactNativeAudioStreaming.createPlayer(this._nativeInstanceId);
  }
  _bindPlayerEvents(){

  }
  play(){
    ReactNativeAudioStreaming.play(this._currentSoundUrl,this._nativeInstanceId);
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
  setPosition(posFloat){

  }
  setSoundUrl(urlString){
    this._currentSoundUrl = urlString;
    if(this.isPlaying()){
       this.stop();
    }
  }
  getSoundUrl(){
    return this._currentSoundUrl;
  }
  getPan(){

  }
  getVolume(){

  }
  isPlaying (){

  }
  getPosition(){

  }
  destroy(){

  }
}
export default ReactNativeStreamingPlayer;
