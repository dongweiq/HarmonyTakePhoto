import grantPermission from './utils/PermissionUtils';
import { PERMISSIONS } from './utils/PermissionUtils';
import { BusinessError } from '@kit.BasicServicesKit';
import { display, router } from '@kit.ArkUI';
import TakePhotoOldUtil from './utils/TakePhotoOldUtil';

@Entry
@Component
struct Index {
  TAG: string = '[Index]';
  private mXComponentController: XComponentController = new XComponentController();
  private surfaceId: string = '-1';

  async aboutToAppear(): Promise<void> {

    await grantPermission(PERMISSIONS).then(res => {
      console.log(this.TAG, `权限申请成功  ${JSON.stringify(res)}`);
      if (this.surfaceId) {
        TakePhotoOldUtil.getInstance().initCamera(this.surfaceId)
      }
    }).catch((rej: BusinessError) => {
      console.log(this.TAG, `权限申请失败  ${JSON.stringify(rej)}`);
    })
  }

  aboutToDisappear(): void {
    TakePhotoOldUtil.getInstance().releaseCamera()
  }

  getShowWidth(): string {
    return display.getDefaultDisplaySync().width + 'px'
  }

  getShowHeight(): string {
    return display.getDefaultDisplaySync().width * this.getScale() + 'px'
  }

  getScale(): number {
    return 1920 / 1080
  }

  onPageShow() {
    TakePhotoOldUtil.getInstance().initCamera(this.surfaceId)
  }

  build() {
    Column() {
      XComponent({
        //预览，同安卓的surfaceview
        id: 'componentId',
        type: 'surface',
        controller: this.mXComponentController
      }).onLoad((event) => {
        //设置预览的宽高
        console.info(this.TAG, 'onLoad is called');
        this.mXComponentController.setXComponentSurfaceSize({ surfaceWidth: 1080, surfaceHeight: 1920 });
        this.surfaceId = this.mXComponentController.getXComponentSurfaceId();
        console.info(this.TAG, `onLoad surfaceId: ${this.surfaceId}`);
        //初始化相机
        TakePhotoOldUtil.getInstance().initCamera(this.surfaceId)
        //设置拍照完成的回调，拿到图像地址
        TakePhotoOldUtil.getInstance().setTakePhotoCallback((path: string) => {
          console.info(this.TAG, `onLoad path: ${path}`)
        })
      })
        .width(this.getShowWidth())
        .height(this.getShowHeight())
      /*Column().width('100%')
        .height('85%')
        .backgroundColor(Color.White)*/
      Row() {
        Button('取消')
          .onClick(() => {
            router.back()
          })
        Button('拍照').onClick(() => {
          TakePhotoOldUtil.getInstance().takePhoto()
        })
        Button('切换').onClick(() => {
          TakePhotoOldUtil.getInstance().switchCamera(this.surfaceId)
        })
      }.width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .height('100%')
      .layoutWeight(1)
    }
    .backgroundColor(Color.Black)
    .width('100%')
    .height('100%')
    .layoutWeight(1)
  }
}