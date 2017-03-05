
# egm0121-react-native-audio-streaming


## Usage

### creating a player instance

```javascript
import { ReactNativeStreamingPlayer } from 'egm0121-react-native-audio-streaming';

const player = new ReactNativeStreamingPlayer();

player.setSoundUrl("http://mydemowebsite.com/stream.mp3");
player.play();
player.pause();
player.resume();

player.getStatus((err,data) => {
  let progress = parseFloat(data.progress);
  let duration = parseFloat(data.duration);
});

player.on('stateChange',(evt) => {});
player.on('RemoteControlEvents',(evt) => {});
player.on('AudioRouteInterruptionEvent',(evt) => {});

player.destroy();
```

## Getting started

`$ npm install react-native-audio-streaming --save`

### Mostly automatic installation

`$ react-native link react-native-audio-streaming`

Go to `node_modules` ➜ `react-native-audio-streaming` => `ios` and add `Pods.xcodeproj`

In XCode, in the project navigator, select your project. Add `libReactNativeAudioStreaming.a` and `libStreamingKit.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`

### Manual installation

#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-audio-streaming` => `ios`
   - run `pod install` to download StreamingKit dependency
   - add `ReactNativeAudioStreaming.xcodeproj`
   - add `Pods/Pods.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libReactNativeAudioStreaming.a` and `libStreamingKit.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)


## Credits

- iOS version based on the work of @tlenclos https://github.com/tlenclos/react-native-audio-streaming
