import { BusinessError } from '@kit.BasicServicesKit';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import PhotoAccessHelper from '@ohos.file.photoAccessHelper';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { GlobalContext } from './GlobalContext';

/**
 * @description 本段代码使用的是最新的api11，目前在鸿蒙上两个测试机上测试时发现一个绿屏一个黑屏，等后期设备更新后，再进行测试
 * @author 王洪贺
 * @date 2024/2/6 11:30
 */
export default class TakePhotoUtil {
  private static photoInstance: TakePhotoUtil;
  context: Context = getContext(this);
  private photoSession?: camera.CaptureSession
  private cameraInput?: camera.CameraInput
  private previewOutput?: camera.PreviewOutput
  private photoOutput?: camera.PhotoOutput
  private backCamera = true
  takePictureHandle?: (photoUri: string) => void

  constructor() {
    this.context = (GlobalContext.getContext().getValue('cameraContext') as common.UIAbilityContext)
  }

  public static getInstance(): TakePhotoUtil {
    if (TakePhotoUtil.photoInstance === undefined) {
      TakePhotoUtil.photoInstance = new TakePhotoUtil();
    }
    return TakePhotoUtil.photoInstance;
  }

  /**
   * 保存图片
   * @param buffer 接收到保存状态通知后得到的数据
   * @param img
   */
  async savePicture(buffer: ArrayBuffer, img: image.Image) {
    let photoAccessHelper: PhotoAccessHelper.PhotoAccessHelper = PhotoAccessHelper.getPhotoAccessHelper(this.context);
    let options: PhotoAccessHelper.CreateOptions = {
      title: Date.now().toString()
    };
    let photoUri: string = await photoAccessHelper.createAsset(PhotoAccessHelper.PhotoType.IMAGE, 'jpg', options);
    //createAsset的调用需要ohos.permission.READ_IMAGEVIDEO和ohos.permission.WRITE_IMAGEVIDEO的权限
    let file: fs.File = fs.openSync(photoUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    await fs.write(file.fd, buffer);
    fs.closeSync(file);
    img.release();
    if (this.takePictureHandle) {
      this.takePictureHandle(photoUri);
    }
  }

  /**
   * 设置拍照完成的回调
   * @param callback
   */
  setTakePhotoCompleteCallback(callback: (path: string) => void): void {
    this.takePictureHandle = callback;
  }

  /**
   * 设置拍照回调
   * @param photoOutput 拍照的输出流
   */
  setPhotoOutputCb() {
    //设置回调之后，调用photoOutput的capture方法，就会将拍照的buffer回传到回调中
    this.photoOutput?.on('photoAvailable', (errCode: BusinessError, photo: camera.Photo): void => {
      console.info('whh:getPhoto start');
      console.info(`whh:err: ${JSON.stringify(errCode)}`);
      if (errCode || photo === undefined) {
        console.error('whh:getPhoto failed');
        return;
      }
      let imageObj = photo.main;
      imageObj?.getComponent(image.ComponentType.JPEG, (errCode: BusinessError, component: image.Component): void => {
        console.info('whh:getComponent start');
        if (errCode || component === undefined) {
          console.error('whh:getComponent failed');
          return;
        }
        let buffer: ArrayBuffer;
        if (component.byteBuffer) {
          buffer = component.byteBuffer;
        } else {
          console.error('whh:byteBuffer is null');
          return;
        }
        this.savePicture(buffer, imageObj);
      });
    });
  }

  /**
   * 创建拍照的相关实例
   * @param baseContext 应用上下文
   * @param surfaceId 组件对应的id
   * @returns
   */
  async openCamera(surfaceId: string, isBackCamera: boolean = true): Promise<void> {
    await this.releaseCamera()
    this.backCamera = isBackCamera
    // 创建CameraManager对象
    let cameraManager: camera.CameraManager = camera.getCameraManager(this.context);
    if (!cameraManager) {
      console.error("whh:camera.getCameraManager error");
      return;
    }
    // 监听相机状态变化
    cameraManager.on('cameraStatus', (err: BusinessError, cameraStatusInfo: camera.CameraStatusInfo) => {
      console.info(`whh:camera : ${cameraStatusInfo.camera.cameraId}`);
      console.info(`whh:status: ${cameraStatusInfo.status}`);
    });

    // 获取相机列表
    let cameraArray: Array<camera.CameraDevice> = cameraManager.getSupportedCameras();
    if (cameraArray.length <= 0) {
      console.error("whh:cameraManager.getSupportedCameras error");
      return;
    }

    for (let index = 0; index < cameraArray.length; index++) {
      console.info('whh:cameraId : ' + cameraArray[index].cameraId); // 获取相机ID
      console.info('whh:cameraPosition : ' + cameraArray[index].cameraPosition); // 获取相机位置
      console.info('whh:cameraType : ' + cameraArray[index].cameraType); // 获取相机类型
      console.info('whh:connectionType : ' + cameraArray[index].connectionType); // 获取相机连接类型
    }

    //TODO 设置前置还是后置相机 后面的cameraArray[0]都需要替换掉
    let cameraDevice: camera.CameraDevice = cameraArray[0];
    if (!this.backCamera) {
      cameraDevice = cameraArray[1];
    }
    // 创建相机输入流
    try {
      this.cameraInput = cameraManager.createCameraInput(cameraDevice);
    } catch (error) {
      let err = error as BusinessError;
      console.error('whh:Failed to createCameraInput errorCode = ' + err.code);
    }
    if (this.cameraInput === undefined) {
      return;
    }

    // 监听cameraInput错误信息

    this.cameraInput.on('error', cameraDevice, (error: BusinessError) => {
      console.error(`Camera input error code: ${error.code}`);
    })

    // 打开相机
    await this.cameraInput.open().catch((error: BusinessError) => {
      console.error(`Camera input open error code: ${error.message}`);
    });

    // 获取支持的模式类型,在dp1的手机上这里一直都是photo mode not support错误，如果注释掉这段代码，相机会显示绿色只有亮度
    let sceneModes: Array<camera.SceneMode> = cameraManager.getSupportedSceneModes(cameraDevice);
    let isSupportPhotoMode: boolean = sceneModes.indexOf(camera.SceneMode.NORMAL_PHOTO) >= 0;
    if (!isSupportPhotoMode) {
      console.error('whh:photo mode not support');
      return;
    }

    //设置预览和输出
    this.setPreviewAndOutPut(cameraManager, cameraDevice, surfaceId);
    //调用上面的回调函数来保存图片
    this.setPhotoOutputCb();
    //创建会话
    await this.startSession(cameraManager);

    //设置闪光灯
    this.setFlashLight(camera.FlashMode.FLASH_MODE_OPEN);
    //设置对焦模式
    this.setFocusParams(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO);
  }

  /**
   * 设置预览和输出流
   * @param cameraManager
   * @param cameraArray
   * @param surfaceId
   */
  private setPreviewAndOutPut(cameraManager: camera.CameraManager, cameraDevice: camera.CameraDevice, surfaceId: string) {
    // 获取相机设备支持的输出流能力
    let cameraOutputCap: camera.CameraOutputCapability = cameraManager.getSupportedOutputCapability(cameraDevice, camera.SceneMode.NORMAL_PHOTO);
    /*if (!cameraOutputCap) {
      console.error("whh:cameraManager.getSupportedOutputCapability error");
      return;
    }*/
    console.info("outputCapability: " + JSON.stringify(cameraOutputCap));

    //获取预览相机相关的配置
    let previewProfilesArray: Array<camera.Profile> = cameraOutputCap.previewProfiles;
    if (!previewProfilesArray) {
      console.error("whh:createOutput previewProfilesArray == null || undefined");
    }

    //TODO 筛选出1920x1080的配置
    // 创建预览输出流,其中参数 surfaceId 参考上文 XComponent 组件，预览流为XComponent组件提供的surface
    let previewProfile: camera.Profile = previewProfilesArray[0];
    for (const item of previewProfilesArray) {
      if (item.size.width === 1920 && item.size.height === 1080) {
        previewProfile = item;
      }
    }
    try {
      this.previewOutput = cameraManager.createPreviewOutput(previewProfile, surfaceId);
    } catch (error) {
      let err = error as BusinessError;
      console.error(`Failed to create the PreviewOutput instance. error code: ${err.code}`);
    }
    /*if (this.previewOutput === undefined) {
      return;
    }*/
    // 监听预览输出错误信息
    this.previewOutput?.on('error', (error: BusinessError) => {
      console.error(`Preview output error code: ${error.code}`);
    });

    //获取可拍照图片相关的配置
    let photoProfilesArray: Array<camera.Profile> = cameraOutputCap.photoProfiles;
    if (!photoProfilesArray) {
      console.error("whh:createOutput photoProfilesArray == null || undefined");
    }
    //TODO 筛选出1920x1080的配置
    let photoProfile: camera.Profile = photoProfilesArray[0];
    for (const item of photoProfilesArray) {
      if (item.size.width === 1920 && item.size.height === 1080) {
        photoProfile = item;
      }
    }
    // 创建拍照输出流
    try {
      this.photoOutput = cameraManager.createPhotoOutput(photoProfile);
    } catch (error) {
      let err = error as BusinessError;
      console.error('whh:Failed to createPhotoOutput errorCode = ' + err.code);
    }
    /*if (this.photoOutput === undefined) {
     return;
   }*/
  }

  /**
   * 启动会话
   * @param cameraManager
   */
  private async startSession(cameraManager: camera.CameraManager) {
    try {
      //TODO 这部分api在api11废弃，只会保留五个版本，但官方没有具体示例，后面再进行修改
      // 官方更新说明  https://developer.huawei.com/consumer/cn/doc/harmonyos-releases/changelogs-camera-0000001777040008
      this.photoSession = cameraManager.createCaptureSession();
    } catch (error) {
      let err = error as BusinessError;
      console.error('whh:Failed to create the session instance. errorCode = ' + err.code);
    }
    /* if (this.photoSession === undefined) {
       return;
     }*/
    // 监听session错误信息
    this.photoSession?.on('error', (error: BusinessError) => {
      console.error(`Capture session error code: ${error.code}`);
    });

    // 开始配置会话
    try {
      this.photoSession?.beginConfig();
    } catch (error) {
      let err = error as BusinessError;
      console.error('whh:Failed to beginConfig. errorCode = ' + err.code);
    }

    // 向会话中添加相机输入流
    try {
      this.photoSession?.addInput(this.cameraInput);
    } catch (error) {
      let err = error as BusinessError;
      console.error('whh:Failed to addInput. errorCode = ' + err.code);
    }

    // 向会话中添加预览输出流
    try {
      this.photoSession?.addOutput(this.previewOutput);
    } catch (error) {
      let err = error as BusinessError;
      console.error('whh:Failed to addOutput(this.previewOutput). errorCode = ' + err.code);
    }

    // 向会话中添加拍照输出流
    try {
      this.photoSession?.addOutput(this.photoOutput);
    } catch (error) {
      let err = error as BusinessError;
      console.error('whh:Failed to addOutput(photoOutput). errorCode = ' + err.code);
    }

    // 提交会话配置
    await this.photoSession?.commitConfig();

    // 启动会话
    await this.photoSession?.start().then(() => {
      console.info('whh:Promise returned to indicate the session start success.');
    });
  }

  /**
   * 设置闪光灯
   */
  private setFlashLight(falshMode: camera.FlashMode) {
    // 判断设备是否支持闪光灯
    let flashStatus: boolean = false;
    try {
      flashStatus = this.photoSession?.hasFlash() || false;
    } catch (error) {
      let err = error as BusinessError;
      console.error('whh:Failed to hasFlash. errorCode = ' + err.code);
    }
    console.info('whh:Returned with the flash light support status:' + flashStatus);

    if (flashStatus) {
      // 判断是否支持自动闪光灯模式
      let flashModeStatus: boolean = false;
      try {
        let status: boolean = this.photoSession?.isFlashModeSupported(camera.FlashMode.FLASH_MODE_AUTO) || false;
        flashModeStatus = status;
      } catch (error) {
        let err = error as BusinessError;
        console.error('whh:Failed to check whether the flash mode is supported. errorCode = ' + err.code);
      }
      if (flashModeStatus) {
        // 设置自动闪光灯模式
        try {
          this.photoSession?.setFlashMode(falshMode);
        } catch (error) {
          let err = error as BusinessError;
          console.error('whh:Failed to set the flash mode. errorCode = ' + err.code);
        }
      }
    }
  }

  /**
   * 设置对焦模式和区域。
   */
  private setFocusParams(focusMode: camera.FocusMode) {
    // 判断是否支持连续自动变焦模式
    let focusModeStatus: boolean = false;
    try {
      let status: boolean = this.photoSession?.isFocusModeSupported(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO) || false;
      focusModeStatus = status;
    } catch (error) {
      let err = error as BusinessError;
      console.error('whh:Failed to check whether the focus mode is supported. errorCode = ' + err.code);
    }

    if (focusModeStatus) {
      // 设置连续自动变焦模式
      try {
        this.photoSession?.setFocusMode(focusMode);
      } catch (error) {
        let err = error as BusinessError;
        console.error('whh:Failed to set the focus mode. errorCode = ' + err.code);
      }
    }

    // 获取相机支持的可变焦距比范围
    let zoomRatioRange: Array<number> = [];
    try {
      zoomRatioRange = this.photoSession?.getZoomRatioRange() || [];
    } catch (error) {
      let err = error as BusinessError;
      console.error('whh:Failed to get the zoom ratio range. errorCode = ' + err.code);
    }
    /*if (zoomRatioRange.length <= 0) {
      return;
    }*/
    // 设置可变焦距比
    try {
      this.photoSession?.setZoomRatio(zoomRatioRange[0]);
    } catch (error) {
      let err = error as BusinessError;
      console.error('whh:Failed to set the zoom ratio value. errorCode = ' + err.code);
    }
  }

  /**
   * 使用当前拍照设置进行拍照
   */
  takePhoto() {
    let photoCaptureSetting: camera.PhotoCaptureSetting = {
      quality: camera.QualityLevel.QUALITY_LEVEL_HIGH, // 设置图片质量高
      rotation: camera.ImageRotation.ROTATION_0 // 设置图片旋转角度0
    }
    this.photoOutput?.capture(photoCaptureSetting, (err: BusinessError) => {
      if (err) {
        console.error(`Failed to capture the photo ${err.message}`);
        return;
      }
      console.info('whh:Callback invoked to indicate the photo capture request success.');
    });
  }

  /**
   * 释放相机资源
   */
  async releaseCamera() {
    await this.photoSession?.stop();

    // 释放相机输入流
    await this.cameraInput?.close();

    // 释放预览输出流
    await this.previewOutput?.release();

    // 释放拍照输出流
    await this.photoOutput?.release();

    // 释放会话
    await this.photoSession?.release();

    // 会话置空
    this.photoSession = undefined;
  }


  switchCamera(surfaceId: string) {
    this.openCamera(surfaceId,!this.backCamera)
  }
}


