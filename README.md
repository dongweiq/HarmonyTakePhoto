## 使用纯血版本鸿蒙开发的自定义相机
### 目前写了两个page，index.ets和takePhoto.ets
默认使用的是api10的接口->index.ets ，目前使用没啥问题
而基于api11接口写的自定义相机测试还有问题，两个测试机一个绿屏一个黑屏，提示不支持（photo mode not support），
关闭这个判断可以执行，但是会有上面的问题，猜测可能是官方的sdk还不太稳定，等升级好了再测试吧

> 项目地址：https://github.com/dongweiq/HarmonyTakePhoto


### 项目截图
![image](./shot/Screenshot_20240208095202012.jpeg)