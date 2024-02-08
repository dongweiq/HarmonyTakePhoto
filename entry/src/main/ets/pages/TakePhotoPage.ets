import { display, router } from '@kit.ArkUI';
import grantPermission, { PERMISSIONS } from './utils/PermissionUtils';
import TakePhotoUtil from './utils/TakePhotoUtil';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct TakePhotoPage {
  private TAG: string = 'TakePhotoPage'
  @State message: string = 'Hello World';
  private mXComponentController: XComponentController = new XComponentController();
  private surfaceId: string = '-1';

  async aboutToAppear(): Promise<void> {

    await grantPermission(PERMISSIONS).then(res => {
      console.log(this.TAG, `权限申请成功  ${JSON.stringify(res)}`);
      if (this.surfaceId) {
        TakePhotoUtil.getInstance().openCamera(this.surfaceId)
      }
    }).catch((rej: BusinessError) => {
      console.log(this.TAG, `权限申请失败  ${JSON.stringify(rej)}`);
    })
  }

  onPageShow() {
    TakePhotoUtil.getInstance().openCamera(this.surfaceId)
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
        TakePhotoUtil.getInstance().openCamera(this.surfaceId)
        console.info(this.TAG, `onLoad surfaceId: ${this.surfaceId}`);
        TakePhotoUtil.getInstance().setTakePhotoCompleteCallback((path) => {
          console.error(this.TAG, `onLoad path: ${path}`);
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
          TakePhotoUtil.getInstance().takePhoto()
        })
        Button('切换').onClick(() => {
          TakePhotoUtil.getInstance().switchCamera(this.surfaceId)
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