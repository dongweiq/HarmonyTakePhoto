import { GlobalContext } from './GlobalContext';
import { common } from '@kit.AbilityKit';
import CameraModel from '../model/CameraModel';

/**
 * @description 本段代码使用的是api10中的相机相关api，目前测试没有问题，api11版本对当前的接口进行了废弃，官方只保留五个版本，所以到api15后必须要改掉
 * @author 王洪贺
 * @date 2024/2/6 17:26
 */
export default class TakePhotoOldUtil {
  private static photoInstance: TakePhotoOldUtil;
  private cameraModel: CameraModel = new CameraModel();
  context: Context = getContext(this);

  constructor() {
    this.context = (GlobalContext.getContext().getValue('cameraContext') as common.UIAbilityContext)
  }

  public static getInstance(): TakePhotoOldUtil {
    if (TakePhotoOldUtil.photoInstance === undefined) {
      TakePhotoOldUtil.photoInstance = new TakePhotoOldUtil();
    }
    return TakePhotoOldUtil.photoInstance;
  }

  /**
   * 初始化相机
   * @param surfaceId
   */
  initCamera(surfaceId: string) {
    this.cameraModel.initCamera(surfaceId);
  }

  /**
   * 设置拍照完成的回调
   * @param callback
   */
  setTakePhotoCallback(callback: (path: string) => void) {
    this.cameraModel.setTakePictureHandleCallback(callback)
  }

  takePhoto() {
    this.cameraModel.takePicture();
  }

  switchCamera(surfaceId: string) {
    this.cameraModel.switchCamera(surfaceId)
  }

  releaseCamera() {
    this.cameraModel.cameraRelease()
  }
}